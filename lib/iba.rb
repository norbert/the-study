# encoding: utf-8

require 'fileutils'

require 'faraday'
require 'nibbler'
require 'nokogiri'
require 'multi_json'
require 'liquid'
require 'active_support/inflector'

module IBA
  BASE_URL = 'http://www.iba-world.com'.freeze

  TEMPLATE =
(
<<LIQUID
# {{ title }}

## Variations

### IBA

{% for ingredient in ingredients %}* {{ ingredient }}
{% endfor %}
{{ description }}
LIQUID
).strip.freeze

  def self.connection
    Faraday.new(BASE_URL) do |builder|
      builder.use Faraday::Response::RaiseError
      builder.adapter Faraday.default_adapter
    end
  end

  def self.execute(command, *args)
    case command
    when "build"
      directory = args[0]
      build(directory, args[1])
    else
      raise NotImplementedError
    end
  end

  def self.build(directory, name = nil)
    FileUtils.mkdir_p(directory)
    list.cocktails.each do |cocktail|
      if name.nil? || cocktail.name == name
        filename = File.join(directory, "#{cocktail.title}.md")
        if !File.symlink?(filename)
          File.open(filename, 'w') do |file|
            file.puts cocktail.render
          end
        end
      end
    end
  end

  def self.list
    @list ||= List.new
  end

  class Page
    def self.connection
      IBA.connection
    end

    def response
      @response ||= self.class.connection.get(url)
    end
    alias_method :get, :response

    def parser
      @parser ||= self.class::Parser.new(response.body).tap(&:parse)
    end

    def as_json
      raise NotImplementedError
    end

    def to_json
      MultiJson.encode(as_json)
    end
  end

  class List < Page
    URL = 'index.php?option=com_content&view=article&id=88&Itemid=532'.freeze

    ROOT = '#cocktails'.freeze

    def url
      URL
    end

    def cocktails
      @cocktails ||= parser.lists.map(&:cocktails).flatten.map { |node|
        Cocktail.build_from_node(node)
      }
    end

    def as_json
      cocktails.map(&:as_json)
    end

    class Parser < Nibbler
      elements "#{ROOT} > ul" => :lists do
        element 'span' => :title
        elements 'li' => :cocktails do
          element 'a' => :name
          element 'a/@href' => :url
        end
      end
    end
  end

  class Cocktail < Page
    ROOT = '.oc_info'.freeze

    SINGLE_QUOTE_CHARACTERS = /’|‘/u.freeze
    DOUBLE_QUOTE_CHARACTERS = /”|“/u.freeze
    WHITESPACE_CHARACTERS = /\p{space}+/u.freeze

    LOWERCASE_WORDS = ['on', 'the'].map(&:downcase).freeze

    attr_reader :url

    def initialize(name, url)
      @name = name
      @url = url
    end

    def self.build_from_node(node)
      new(node.name, node.url)
    end

    def raw_name
      @name ||= parser.info.name
    end

    def stripped_name
      raw_name.gsub(SINGLE_QUOTE_CHARACTERS, "'").strip
    end
    alias_method :name, :stripped_name

    def group
      parser.info.group
    end

    def title
      name.split(WHITESPACE_CHARACTERS).map { |word|
        if word_ = LOWERCASE_WORDS.find { |w_| w_ == word.downcase }
          word_
        else
          word.capitalize.gsub(/(-[a-z])/) { $1.upcase }
        end
      }.join(' ')
    end

    def ingredients
      @ingredients ||= parser.info.list.ingredients.map { |node|
        Ingredient.parse(node)
      }
    end

    def description
      if !instance_variable_defined?(:@description)
        doc = parser.info.doc
        node = doc.children[4]
        text = node.text.
          gsub(WHITESPACE_CHARACTERS, " ").
          gsub(SINGLE_QUOTE_CHARACTERS, "'").
          gsub(DOUBLE_QUOTE_CHARACTERS, "\"").
          strip
        if node.to_html.include?('<br>')
          text.gsub!(/(.)\.([A-Z])/) do
            "#{$1}. #{$2}"
          end
        end
        text.gsub!(/\s+Variations:$/, "")
        text.gsub!(/\s\(note:.*$/, ".")
        @description = text
      else
        @description
      end
    end

    def as_json
      {
        name: name,
        url: url,
        ingredients: ingredients,
        description: description
      }
    end

    module Rendering
      def template
        @template ||= Liquid::Template.parse(TEMPLATE)
      end

      def ingredients_for_template
        ingredients.map { |(text, quantity, unit)|
          ingredient_for_template(text, quantity, unit)
        }
      end

      def ingredient_for_template(text, quantity = nil, unit = nil)
        if quantity
          "**#{quantity_for_template(quantity, unit)}** #{text}"
        else
          text
        end
      end

      def quantity_for_template(quantity, unit = nil)
        quantity = quantity.to_s.sub(/\.0$/u, '')
        if unit
          quantity.concat(" #{quantity == "1" ? unit : unit.pluralize}")
        end
        quantity
      end

      def render
        output = template.render(
          'title' => title,
          'ingredients' => ingredients_for_template,
          'description' => description
        )
        output.strip
      end
    end

    include Rendering

    class Parser < Nibbler
      element ROOT => :info do
        element '.info1' => :name
        element '.info2' => :type

        element '.list' => :list do
          elements 'li' => :ingredients
        end
      end
    end

    class Ingredient
      UNITS = ['dash', 'splash', 'drop'].freeze

      ABBREVIATIONS = {
        'cl' => 'cl',
        'ml' => 'ml',
        'teaspoon' => 'tsp',
        'bar spoon' => 'bsp'
      }.freeze
      ABBREVIATED_UNITS = ABBREVIATIONS.keys.freeze
      ActiveSupport::Inflector.inflections.uncountable(
        *ABBREVIATIONS.values
      )

      PLURAL_UNITS = (UNITS + ABBREVIATED_UNITS).map { |unit|
        unit.pluralize
      }.freeze

      QUANTITY = /\d+(\.\d+)?( to \d)?/.freeze

      MATCHER = Regexp.compile("^\\b(#{QUANTITY})( (" +
        (UNITS + ABBREVIATED_UNITS + PLURAL_UNITS).uniq.map { |unit|
          "(#{unit})"
        }.join('|') + "))?( of)? (.+)$", Regexp::IGNORECASE)

      def self.parse(text)
        text = text.
          gsub(WHITESPACE_CHARACTERS, " ").
          gsub(SINGLE_QUOTE_CHARACTERS, "'").
          strip

        if match = text.match(MATCHER)
          quantity = Float(match[1]) rescue match[1]
          if !match[5].nil?
            unit = match[5].downcase
          end
          text = match[-1]

          if PLURAL_UNITS.include?(unit)
            unit = unit.singularize
          end

          if unit == 'cl'
            quantity = (quantity * 10).ceil
            unit = 'ml'
          elsif abbreviation = ABBREVIATIONS[unit]
            unit = abbreviation
          end

          [text, quantity, unit]
        else
          [text.capitalize]
        end
      end
    end
  end
end
