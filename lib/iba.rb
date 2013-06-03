require 'fileutils'

require 'faraday'
require 'nibbler'
require 'nokogiri'
require 'multi_json'
require 'liquid'
require 'active_support/inflector'

module IBA
  BASE_URL = 'http://www.iba-world.com'

  TEMPLATE = <<LIQUID
# {{ title }}

## Variations

### IBA

{% for ingredient in ingredients %}* {{ ingredient }}
{% endfor %}
{{ description }}
LIQUID

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
        File.open(File.join(directory, "#{cocktail.title}.md"), 'w') do |file|
          file.puts cocktail.render
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
    URL = 'index.php?option=com_content&view=article&id=88&Itemid=532'
    ROOT = '#cocktails'

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
    ROOT = '.oc_info'

    attr_reader :name, :url

    def initialize(name, url)
      @name = name
      @url = url
    end

    def self.build_from_node(node)
      new(node.name, node.url)
    end

    def name
      @name ||= parser.info.info.name
    end

    def title
      ActiveSupport::Inflector.titleize(name)
    end

    def ingredients
      @ingredients ||= parser.info.list.ingredients.map { |node|
        Ingredient.parse(node)
      }
    end

    def description
      if !instance_variable_defined?(:@description)
        root = parser.doc.search(ROOT).first
        node = root.children[4]
        @description = node.text.strip
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

    def template
      @template ||= Liquid::Template.parse(TEMPLATE)
    end

    def ingredients_for_template
      ingredients.map { |(text, quantity, unit)|
        quantity ? "**#{quantity_for_template(quantity, unit)}** #{text}" : text
      }
    end

    def quantity_for_template(quantity, unit)
      quantity = quantity.to_s.sub(/\.0$/, '')
      quantity.concat(" #{unit}") if unit
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

    class Parser < Nibbler
      element ROOT => :info do
        element '.info' => :info do
          element '.info1' => :name
          element '.info2' => :type
        end

        element '.list' => :list do
          elements 'li' => :ingredients
        end
      end
    end

    class Ingredient
      PARSER = /\b(\d+(\.\d+)?) (\w+) (.+)/

      def self.parse(text)
        text = text.strip
        if text =~ PARSER
          quantity = Float($1)
          unit = $3
          text = $4.strip
          if unit == "cl"
            quantity = (quantity * 10).ceil
            unit = "ml"
          else
            text = "#{unit} #{text}"
            unit = nil
          end
          [text, quantity, unit]
        else
          [text]
        end
      end
    end
  end
end
