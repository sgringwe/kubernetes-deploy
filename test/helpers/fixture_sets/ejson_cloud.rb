# frozen_string_literal: true
module FixtureSetAssertions
  class EjsonCloud < FixtureSet
    def initialize(namespace)
      @namespace = namespace
      @app_name = "ejson-cloud"
    end

    def assert_all_up
      assert_all_secrets_present
      assert_web_resources_up
    end

    def create_ejson_keys_secret
      metadata = {
        name: 'ejson-keys',
        namespace: namespace,
        labels: { name: 'ejson-keys' }
      }
      encoded_data = {
        "65f79806388144edf800bf9fa683c98d3bc9484768448a275a35d398729c892a" =>
          "ZmVkY2M5NTEzMmU5YjM5OWVlMWY0MDQzNjRmZGJjODFiZGJlNGZlYjViODI5MmIwNjFmMTAyMjQ4MTE1N2Q1YQ=="
      }
      secret = Kubeclient::Secret.new(type: 'Opaque', metadata: metadata, data: encoded_data)
      kubeclient.create_secret(secret)
    end

    def assert_all_secrets_present
      assert_secret_present("ejson-keys")
      cert_data = { "tls.crt" => "this-is-the-certificate", "tls.key" => "this-is-the-key" }
      assert_secret_present("catphotoscom", cert_data, type: "kubernetes.io/tls", managed: true)
      assert_secret_present("monitoring-token", { "api-token" => "this-is-the-api-token" }, managed: true)
      assert_secret_present("unused-secret", { "this-is-for-testing-deletion" => "true" }, managed: true)
    end

    def assert_web_resources_up
      assert_pod_status("web", "Running")
      assert_deployment_up("web", replicas: 1)
    end
  end
end
