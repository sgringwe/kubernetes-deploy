module KubernetesDeploy
  module DeferredSummaryLogging
    attr_reader :summary
    def initialize(*args)
      reset
      super
    end

    def reset
      @summary = DeferredSummary.new
      @current_phase = 0
    end

    def blank_line(level = :info)
      public_send(level, "")
    end

    def phase_heading(phase_name)
      @current_phase += 1
      heading("Phase #{@current_phase}: #{phase_name}")
    end

    def heading(text, secondary_msg='', secondary_msg_color=:blue)
      padding = (100.0 - (text.length + secondary_msg.length)) / 2
      blank_line
      part1 = ColorizedString.new("#{'-' * padding.floor}#{text}").blue
      part2 = ColorizedString.new(secondary_msg).colorize(secondary_msg_color)
      part3 = ColorizedString.new("#{'-' * padding.ceil}").blue
      info(part1 + part2 + part3)
    end

    def print_summary(success)
      if success
        heading("Result: ", "SUCCESS", :green)
        level = :info
      else
        heading("Result: ", "FAILURE", :red)
        level = :fatal
      end

      public_send(level, summary.actions_sentence)
      summary.paragraphs.each do |para|
        blank_line
        msg_lines = para.split("\n")
        msg_lines.each { |line| public_send(level, line) }
      end
    end

    class DeferredSummary
      attr_reader :paragraphs, :actions_taken
      attr_accessor :failure_reason

      def initialize
        @actions_taken = []
        @paragraphs = []
        @failure_reason = ""
      end

      def actions_sentence
        sent = case actions_taken.length
        when 0 then
          return "No actions taken"
        when 1 then actions_taken.first
        when 2 then actions_taken.join(" and ")
        else
          actions_taken[0..-2].join(", ") + " and " + actions_taken[-1]
        end
        sent.capitalize
      end

      def add_action(sentence_fragment)
        @actions_taken << sentence_fragment
      end

      def add_paragraph(paragraph)
        paragraphs << paragraph
      end
    end
  end
end
