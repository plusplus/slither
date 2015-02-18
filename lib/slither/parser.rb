class Slither
  class Parser

    def initialize(definition, file_io)
      @definition = definition
      @file = file_io
      # This may be used in the future for non-linear or repeating sections
      @mode = :linear
      @length_validation = definition.options[:length_validation]
    end

    attr_accessor :length_validation

    def parse(collector = nil)
      collector ||= default_collector

      @file.each_line do |line|
        line.chomp! if line
        next if line.empty?
        @definition.sections.each do |section|
          if section.match(line)
            validate_length(line, section)
            collector.process_record(section.name, section.parse(line))
          end
        end
      end
      collector.finished
    end

    def parse_by_bytes(collector = nil)
      collector ||= default_collector

      all_section_lengths = @definition.sections.map{|sec| sec.length }
      byte_length = all_section_lengths.max
      all_section_lengths.each { |bytes| raise(Slither::SectionsNotSameLengthError,
          "All sections must have the same number of bytes for parse by bytes") if bytes != byte_length }

      while record = @file.read(byte_length)

        unless remove_newlines! && byte_length == record.length
          parsed_line = parse_for_error_message(record)
          raise(Slither::LineWrongSizeError, "Line wrong size: No newline at #{byte_length} bytes. #{parsed_line}")
        end

        record.force_encoding @file.external_encoding

        @definition.sections.each do |section|
          if section.match(record)
            collector.process_record(section.name, section.parse(record))
          end
        end
      end

      collector.validate!
      collector.finished
    end

    private

      def default_collector
        SimpleCollector.new(@definition)
      end

      def validate_length(line, section)
        unless length_valid?(line, section)
          parsed_line = parse_for_error_message(line)
          raise Slither::LineWrongSizeError, "Line wrong size: (#{line.length} when it should be #{section.length}. #{parsed_line})"
        end
      end

      def length_valid?(line, section)
        case length_validation
        when :strict
          line.length == section.length
        when :ignore_extra_columns
          line.length >= section.length
        else
          line.length >= section.length ||
          section.column_boundary?(line.length)
        end
      end

      def remove_newlines!
        return true if @file.eof?
        b = @file.getbyte
        if b == 10 || b == 13 && @file.getbyte == 10
          return true
        else
          @file.ungetbyte b
          return false
        end
      end

      def newline?(char_code)
        # \n or LF -> 10
        # \r or CR -> 13
        [10, 13].any?{|code| char_code == code}
      end

      def parse_for_error_message(line)
        parsed = ''
        line.force_encoding @file.external_encoding
        @definition.sections.each do |section|
          if section.match(line)
            parsed = section.parse_when_problem(line)
          end
        end
        parsed
      end

  end
end