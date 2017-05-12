# frozen_string_literal: true
module KubernetesDeploy
  class FatalDeploymentError < StandardError
    def debug_info
      @debug_info ||= []
    end

    def add_debug_info(paragrah)
      debug_info << paragrah
    end
  end

  class KubectlError < StandardError; end

  class NamespaceNotFoundError < FatalDeploymentError
    def initialize(name, context)
      super("Namespace `#{name}` not found in context `#{context}`. Aborting the task.")
    end
  end
end
