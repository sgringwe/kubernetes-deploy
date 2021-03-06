# frozen_string_literal: true
module KubernetesDeploy
  class PodDisruptionBudget < KubernetesResource
    TIMEOUT = 10.seconds

    def initialize(name, namespace, context, file)
      @name = name
      @namespace = namespace
      @context = context
      @file = file
    end

    def sync
      _, _err, st = run_kubectl("get", type, @name)
      @found = st.success?
      @status = @found ? "Available" : "Unknown"
      log_status
    end

    def deploy_succeeded?
      exists?
    end

    def deploy_method
      # Required until https://github.com/kubernetes/kubernetes/issues/45398 changes
      :replace_force
    end

    def exists?
      @found
    end
  end
end
