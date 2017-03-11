module KubernetesDeploy
  class ReplicaSet < KubernetesResource
    TIMEOUT = 5.minutes

    def initialize(name, namespace, context, file, parent: nil)
      @name, @namespace, @context, @file, @parent = name, namespace, context, file, parent
      @bare = !@parent
    end

    def sync
      json_data, st = run_kubectl("get", type, @name, "--output=json")
      @found = st.success?
      @rollout_data = {}
      @status = nil
      @pods = []

      if @found
        rs_data = JSON.parse(json_data)
        @rollout_data = rs_data["status"].slice(
          "replicas",
          "availableReplicas",
          "readyReplicas",
          # "unavailableReplicas"
        ) # need to check what keys for bad statuses are called

        selectors = rs_data["spec"]["selector"]["matchLabels"]
        label_list = selectors.map { |name, value| "#{name}=#{value}" }.join(",")

        pod_list, st = run_kubectl("get", "pods", "-a", "-l", label_list, "--output=json")
        if st.success?
          pods_json = JSON.parse(pod_list)["items"]
          pods_json.each do |pod_json|
            pod_name = pod_json["metadata"]["name"]
            pod = Pod.new(pod_name, namespace, context, nil, parent: @parent || "#{@name} replica set")
            pod.deploy_started = @deploy_started
            pod.interpret_json_data(pod_json)
            @pods << pod
          end
        end
      end

      log_status
    end

    def deploy_failed?
     @pods.present? && @pods.all?(&:deploy_failed?)
    end

    def deploy_succeeded?
      @rollout_data["readyReplicas"] == @rollout_data["replicas"] # what is available vs these?
    end

    def deploy_timed_out?
      super || @pods.present? && @pods.all?(&:deploy_timed_out?)
    end

    def exists?
      @found
    end
  end
end
