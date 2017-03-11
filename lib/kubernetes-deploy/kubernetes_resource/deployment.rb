module KubernetesDeploy
  class Deployment < KubernetesResource
    TIMEOUT = 5.minutes

    def initialize(name, namespace, context, file)
      @name, @namespace, @context, @file = name, namespace, context, file
    end

    def sync
      json_data, st = run_kubectl("get", type, @name, "--output=json")
      @found = st.success?
      @rollout_data = {}
      @status = @new_replica_set = nil

      if @found
        deployment_data = JSON.parse(json_data)
        @rollout_data = deployment_data["status"].slice(
          "updatedReplicas",
          "replicas",
          "availableReplicas",
          "unavailableReplicas"
        )
        @status, _ = run_kubectl("rollout", "status", type, @name, "--watch=false") if @deploy_started

        # To be replaced with controllerRef-based rs discovery when available
        # https://github.com/kubernetes/kubernetes/issues/24946
        # https://github.com/kubernetes/kubernetes/pull/35676 (v1.6 milestone)
        description, st = run_kubectl("describe", type, @name)
        description.match(/^NewReplicaSet\:\s+(?<new_rs_name>\S+)/) do |matchdata|
          @new_replica_set = ReplicaSet.new(matchdata[:new_rs_name], namespace, context, nil, parent: "#{@name.capitalize} deployment")
          @new_replica_set.deploy_started = @deploy_started
        end
        @new_replica_set.sync if @new_replica_set
      end

      log_status
    end

    def deploy_succeeded?
      # Note that the describe output will declare the rollout finished once desired - maxUnavailable is reached
      # https://github.com/kubernetes/kubernetes/blob/a22fac00dd389afa0baaa1fe28114847d843f740/pkg/kubectl/rollout_status.go#L69-L84
      @new_replica_set && @new_replica_set.deploy_succeeded? # what if desired is 0... is there a new rs?
    end

    def deploy_failed?
      @new_replica_set && @new_replica_set.deploy_failed?
    end

    def deploy_timed_out?
      super || @new_replica_set && @new_replica_set.deploy_timed_out?
    end

    def exists?
      @found
    end

    def status_data
      data = { replicas: @rollout_data }
      data.merge(new_replica_set: @new_replica_set.status_data) if @new_replica_set
      super.merge(data)
    end
  end
end
