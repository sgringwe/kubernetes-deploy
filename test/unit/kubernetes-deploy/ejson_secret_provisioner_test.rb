# frozen_string_literal: true
require 'test_helper'

class EjsonSecretProvisionerTest < KubernetesDeploy::TestCase
  def test_secrets_requested?
    refute build_provisioner(fixture_path('hello-cloud')).secrets_requested?
    assert build_provisioner(fixture_path('ejson-cloud')).secrets_requested?
  end

  def test_create_secrets_with_secrets_file_missing
    assert_raises_message(KubernetesDeploy::EjsonSecretError, /secrets.ejson not found/) do
      build_provisioner(fixture_path('hello-cloud')).create_secrets
    end
  end

  def test_create_secrets_with_secrets_file_invalid_json
    assert_raises_message(KubernetesDeploy::EjsonSecretError, /Failed to parse encrypted ejson/) do
      with_ejson_file("}") do |target_dir|
        build_provisioner(target_dir).create_secrets
      end
    end
  end

  def test_create_secrets_with_ejson_keypair_mismatch
    wrong_data = {
      "2200e55f22dd0c93fac3832ba14842cc75fa5a99a2e01696daa30e188d465036" =>
        "MTM5ZDVjMmEzMDkwMWRkOGFlMTg2YmU1ODJjY2MwYTg4MmMxNmY4ZTBiYjU0Mjk4ODRkYmM3Mjk2ZTgwNjY5ZQo="
    }
    mock_kubeclient.expects(:get_secret).with('ejson-keys', 'test').returns("data" => wrong_data)

    msg = "Private key for 65f79806388144edf800bf9fa683c98d3bc9484768448a275a35d398729c892a not found"
    assert_raises_message(KubernetesDeploy::EjsonSecretError, msg) do
      build_provisioner.create_secrets
    end
  end

  def test_create_secrets_with_bad_private_key_in_cloud_keys
    wrong_private = {
      "65f79806388144edf800bf9fa683c98d3bc9484768448a275a35d398729c892a" =>
        "MTM5ZDVjMmEzMDkwMWRkOGFlMTg2YmU1ODJjY2MwYTg4MmMxNmY4ZTBiYjU0Mjk4ODRkYmM3Mjk2ZTgwNjY5ZQo="
    }
    mock_kubeclient.expects(:get_secret).with('ejson-keys', 'test').returns("data" => wrong_private)
    assert_raises_message(KubernetesDeploy::EjsonSecretError, /Decryption failed/) do
      build_provisioner.create_secrets
    end
  end

  def test_create_secrets_with_cloud_keys_secret_missing
    mock_kubeclient.expects(:get_secret).with('ejson-keys', 'test').raises(KubeException.new(404, "not found", nil))
    assert_raises_message(KubernetesDeploy::EjsonSecretError, /secret ejson-keys not found in namespace test/) do
      build_provisioner.create_secrets
    end
  end

  def test_create_secrets_with_file_missing_section_for_managed_secrets_logs_warning
    mock_kubeclient.expects(:get_secret).with('ejson-keys', 'test').returns("data" => correct_ejson_key_secret_data)
    new_content = { "_public_key" => fixture_public_key, "not_the_right_key" => [] }

    with_ejson_file(new_content) do |target_dir|
      build_provisioner(target_dir).create_secrets
    end
    assert_logs_match("No secrets will be created.")
  end

  def test_create_secret_with_incomplete_secret_spec
    mock_kubeclient.expects(:get_secret).with('ejson-keys', 'test').returns("data" => correct_ejson_key_secret_data)
    new_content = {
      "_public_key" => fixture_public_key,
      "kubernetes_secrets" => { "foobar" => {} }
    }

    msg = "Ejson incomplete for secret foobar: secret type unspecified, no data provided"
    assert_raises_message(KubernetesDeploy::EjsonSecretError, msg) do
      with_ejson_file(new_content) do |target_dir|
        build_provisioner(target_dir).create_secrets
      end
    end
  end

  def test_prune_managed_ejson_secrets_with_no_secrets_in_ejson_does_nothing
    mock_kubeclient.expects(:get_secrets).with(namespace: 'test').returns([])
    new_content = { "_public_key" => fixture_public_key, "not_the_right_key" => [] }
    with_ejson_file(new_content) do |target_dir|
      build_provisioner(target_dir).prune_managed_secrets
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
