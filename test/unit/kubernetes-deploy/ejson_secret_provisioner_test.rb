# frozen_string_literal: true
require 'test_helper'

class EjsonSecretProvisionerTest < KubernetesDeploy::TestCase
  def test_run_with_secrets_file_invalid_json
    assert_raises_message(KubernetesDeploy::EjsonSecretError, /Failed to parse encrypted ejson/) do
      with_ejson_file("}") do |target_dir|
        build_provisioner(target_dir).run
      end
    end
  end

  private

  def correct_ejson_key_secret_data
    {
      fixture_public_key => "ZmVkY2M5NTEzMmU5YjM5OWVlMWY0MDQzNjRmZGJjODFiZGJlNGZlYjViODI5MmIwNjFmMTAyMjQ4MTE1N2Q1YQ=="
    }
  end

  def fixture_public_key
    "65f79806388144edf800bf9fa683c98d3bc9484768448a275a35d398729c892a"
  end

  def with_ejson_file(content)
    Dir.mktmpdir do |target_dir|
      File.write(File.join(target_dir, KubernetesDeploy::EjsonSecretProvisioner::EJSON_SECRETS_FILE), content.to_json)
      yield target_dir
    end
  end

  def mock_kubeclient
    @mock_kubeclient ||= mock('kubeclient')
  end

  def build_provisioner(dir = nil)
    dir ||= fixture_path('ejson-cloud')
    KubernetesDeploy::EjsonSecretProvisioner.new(
      namespace: 'test',
      template_dir: dir,
      client: mock_kubeclient
    )
  end
end
