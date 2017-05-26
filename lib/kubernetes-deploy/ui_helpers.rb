# frozen_string_literal: true
module KubernetesDeploy
  module UIHelpers
    private

    def phase_heading(phase_name)
      @current_phase ||= 0
      @current_phase += 1
      heading("Phase #{@current_phase}: #{phase_name}")
    end

    def heading(text, secondary_msg='', secondary_msg_color=:blue, line_color: :blue, delimiter: "-")
      padding = (100.0 - (text.length + secondary_msg.length)) / 2
      @logger.info("")
      part1 = ColorizedString.new("#{delimiter * padding.floor}#{text}").colorize(line_color)
      part2 = ColorizedString.new(secondary_msg).colorize(secondary_msg_color)
      part3 = ColorizedString.new("#{delimiter * padding.ceil}").colorize(line_color)
      @logger.info(part1 + part2 + part3)
    end

    def report_deploy_failure(message, debug_info)
      heading("Deploy result: ", "FAILURE", :red)
      @logger.fatal(message)
      return if debug_info.empty?

      debug_info.each do |para|
        @logger.blank_line(:fatal)
        msg_lines = para.split("\n")
        msg_lines.each { |line| @logger.fatal(line) }
      end
    end

    def report_deploy_success(resources, secret_actions:)
      heading("Deploy result: ", "SUCCESS", :green)
      actions = ["Deployed #{resources.length} #{'resource'.pluralize(resources.length)}"] + secret_actions
      actions_sentence = actions[0..-2].join(", ") + " and " + actions[-1]

      @logger.info("#{actions_sentence} in #{Time.now.utc - @started_at}s")
      @logger.blank_line
      resources.each { |r| @logger.info(r.pretty_status) }
    end
  end
end
