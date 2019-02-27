module StateOfTheNation
  class ConflictError < StandardError
    def initialize(record, conflicting_records)
      super(<<-MSG.strip_heredoc)
        Attempted to commit record

          #{record.inspect}

        But encountered a conflict with timestamps on the following records

          #{conflicting_records.map { |record| "- #{record.inspect}" }.join("\n")}

      MSG
    end
  end
end
