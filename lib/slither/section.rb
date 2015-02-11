class Slither
  class Section
    attr_accessor :definition, :optional
    attr_reader :name, :columns, :options, :length

    RESERVED_NAMES = [:spacer]

    def initialize(name, options = {})
      @name = name
      @options = options
      @columns = []
      @trap = options[:trap]
      @optional = options[:optional] || false
      @length = 0
    end

    def column(name, length, options = {})
      raise(Slither::DuplicateColumnNameError, "You have already defined a column named '#{name}'.") if @columns.map do |c|
        RESERVED_NAMES.include?(c.name) ? nil : c.name
      end.flatten.include?(name)
      col = Column.new(name, length, @options.merge(options))
      @columns << col
      @length += length
      col
    end

    def spacer(length)
      column(:spacer, length)
    end

    def trap(&block)
      @trap = block
    end

    def template(name)
      template = @definition.templates[name]
      raise ArgumentError, "Template #{name} not found as a known template." unless template
      @columns += template.columns
      @length += template.length
      # Section options should trump template options
      @options = template.options.merge(@options)
    end

    def format(data)
      # raise( ColumnMismatchError,
      #   "The '#{@name}' section has #{@columns.size} column(s) defined, but there are #{data.size} column(s) provided in the data."
      # ) unless @columns.size == data.size
      row = ''
      @columns.each do |column|
        row += column.format(data[column.name])
      end
      row
    end

    def column_boundary?(length)
      boundary = 0
      columns.each do |column|
        boundary += column.length
        return true if length == boundary
      end
      false
    end

    def parse(line)
      line_data = unpack(line)
      row = {}
      @columns.each_with_index do |c, i|
        row[c.name] = c.parse(line_data[i]) unless RESERVED_NAMES.include?(c.name)
      end
      row
    end

    def parse_when_problem(line)
      line_data = line.unpack(@columns.map { |c| "a#{c.length}" }.join(''))
      row = ''
      @columns.each_with_index do |c, i|
        row << "\n'#{c.name}':'#{line_data[i]}'" unless RESERVED_NAMES.include?(c.name)
      end
      row
    end

    def match(raw_line)
      raw_line.nil? ? false : @trap.call(raw_line)
    end

    def method_missing(method, *args)
      column(method, *args)
    end

    private

    # Can't use String#unpack as it has no idea about character encodings
    # Extract array of raw string data values from the line based on column
    # widths
    def unpack(line)
      column_slices.map { |start, length| line[start, length] }
                   .map { |value| clean(value) }
    end

    # Remove trailing spaces
    def clean(cell)
      return '' if cell.nil?
      cell.gsub(/ +\z/, '')
    end

    def column_slices
      return @slices if @slices

      @slices = []
      start_index = 0
      @columns.map(&:length).each do |l|
        @slices << [start_index, l]
        start_index += l
      end
      @slices
    end
  end
end