# frozen_string_literal: true
require 'json'
require 'open3'
require 'shellwords'
require 'kubernetes-deploy/kubectl'

module KubernetesDeploy
  class KubernetesResource
    attr_reader :name, :namespace, :file, :context
    attr_writer :type, :deploy_started

    TIMEOUT = 5.minutes

    DEBUG_RESOURCE_NOT_FOUND_MESSAGE = "None found. Please check your usual logging service (e.g. Splunk)."
    UNUSUAL_FAILURE_MESSAGE = <<-MSG.strip_heredoc.strip
      It is very unusual for this resource type to fail to deploy. Please try the deploy again,
      and contact your cluster administrator if it still fails.
      MSG
    STANDARD_TIMEOUT_MESSAGE = <<-MSG.strip_heredoc.strip
      Kubernetes will continue to attempt to deploy this resource in the cluster, but at this point it is considered unlikely that it will succeed.
      If you have reason to believe it will succeed, retry the deploy to continue to monitor the rollout.
      MSG

    def self.for_type(type:, name:, namespace:, context:, file:, logger:)
      subclass = case type
      when 'cloudsql' then Cloudsql
      when 'configmap' then ConfigMap
      when 'deployment' then Deployment
      when 'pod' then Pod
      when 'redis' then Redis
      when 'bugsnag' then Bugsnag
      when 'ingress' then Ingress
      when 'persistentvolumeclaim' then PersistentVolumeClaim
      when 'service' then Service
      when 'podtemplate' then PodTemplate
      when 'poddisruptionbudget' then PodDisruptionBudget
      end

      opts = { name: name, namespace: namespace, context: context, file: file, logger: logger }
      if subclass
        subclass.new(**opts)
      else
        inst = new(**opts)
        inst.tap { |r| r.type = type }
      end
    end

    def self.timeout
      self::TIMEOUT
    end

    def timeout
      self.class.timeout
    end

    def initialize(name:, namespace:, context:, file:, logger:)
      # subclasses must also set these if they define their own initializer
      @name = name
      @namespace = namespace
      @context = context
      @file = file
      @logger = logger
    end

    def id
      "#{type}/#{name}"
    end

    def sync
    end

    def deploy_failed?
      false
    end

    def deploy_succeeded?
      if @deploy_started && !@success_assumption_warning_shown
        @logger.warn("Don't know how to monitor resources of type #{type}. Assuming #{id} deployed successfully.")
        @success_assumption_warning_shown = true
      end
      true
    end

    def exists?
      nil
    end

    def status
      @status ||= "Unknown"
    end

    def type
      @type || self.class.name.split('::').last
    end

    def deploy_finished?
      deploy_failed? || deploy_succeeded? || deploy_timed_out?
    end

    def deploy_timed_out?
      return false unless @deploy_started
      !deploy_succeeded? && !deploy_failed? && (Time.now.utc - @deploy_started > timeout)
    end

    def tpr?
      false
    end

    # Expected values: :apply, :replace, :replace_force
    def deploy_method
      # TPRs must use update for now: https://github.com/kubernetes/kubernetes/issues/39906
      tpr? ? :replace : :apply
    end

    def group_name
      type.downcase.pluralize
    end

    def debug_message
      helpful_info = []
      if deploy_failed?
        helpful_info << ColorizedString.new("#{id}: FAILED").red
        helpful_info << failure_message if failure_message.present?
      else
        helpful_info << "#{ColorizedString.new("#{id }: TIMED OUT").yellow} (limit: #{timeout}s)"
        helpful_info << timeout_message if timeout_message.present?
      end
      helpful_info << "  - Final status: #{status}"

      events = get_events
      if events.present?
        helpful_info << "  - Events:"
        events.each { |event| helpful_info << "      [#{id}/events]\t#{event.to_json}" }
      else
        helpful_info << "  - Events: #{DEBUG_RESOURCE_NOT_FOUND_MESSAGE}"
      end

      if respond_to?(:get_logs)
        container_logs = get_logs
        if container_logs.blank? || container_logs.values.all?(&:blank?)
          helpful_info << "  - Logs: #{DEBUG_RESOURCE_NOT_FOUND_MESSAGE}"
        else
          helpful_info << "  - Logs:"
          container_logs.each do |container_name, logs|
            logs.split("\n").each do |line|
              helpful_info << "      [#{id}/#{container_name}/logs]\t#{line}"
            end
          end
        end
      end

      helpful_info.join("\n")
    end

    def get_events
      return unless exists?
      out, _err, st = kubectl.run("get", "events", %(--output=jsonpath={range .items[?(@.involvedObject.name=="#{name}")]}{.involvedObject.kind}\t{.count}\t{.message}\t{.reason}\t{.type}\n{end}))
      return unless st.success?
      event_hashes = out.split("\n").each_with_object([]) do |event_blob, events|
        pieces = event_blob.split("\t")
        event = {
          "subject_kind" => pieces[0],
          "count" => pieces[1],
          "message" => pieces[2],
          "reason" => pieces[3],
          "type" => pieces[4]
        }
        events << event if event["subject_kind"].downcase == type.downcase
      end
      event_hashes
    end

    def timeout_message
      STANDARD_TIMEOUT_MESSAGE
    end

    def failure_message
    end

    def pretty_status
      padding = " " * (50 - id.length)
      msg = exists? ? status : "not found"
      "#{id}#{padding}#{msg}"
    end

    def kubectl
      @kubectl ||= Kubectl.new(namespace: @namespace, context: @context, logger: @logger, log_failure_by_default: false)
    end
  end
end
