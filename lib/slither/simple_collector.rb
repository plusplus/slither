class Slither
  class SimpleCollector

    attr_accessor :parsed

    def initialize(definition)
      @definition = definition
      @parsed = {}
    end

    def line(section_type, data)
      parsed[section_type] ||= []
      parsed[section_type] << data
    end

    def finished
      validate!
      parsed
    end

    def validate!
      @definition.sections.each do |section|
        unless parsed[section.name] || section.optional
          raise(
            Slither::RequiredSectionNotFoundError,
            "Required section '#{section.name}' was not found."
          )
        end
      end
    end
  end
end