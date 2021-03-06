# frozen_string_literal: true
module KubernetesDeploy
  class PodTemplate < KubernetesResource
    def initialize(name, namespace, context, file)
      @name = name
      @namespace = namespace
      @context = context
      @file = file
    end

    def sync
      _, _err, st = run_kubectl("get", type, @name)
      @status = st.success? ? "Available" : "Unknown"
      @found = st.success?
      log_status
    end

    def deploy_succeeded?
      exists?
    end

    def deploy_failed?
      false
    end

    def exists?
      @found
    end
  end
end
