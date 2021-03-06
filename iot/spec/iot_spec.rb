# Copyright 2018 Google, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "google/apis/cloudiot_v1"
require "google/cloud/pubsub"
require "rspec"
require "securerandom"
require "tempfile"
require_relative "../iot"

describe "Cloud IoT Core" do

  before do
    @project_id = ENV["GOOGLE_CLOUD_PROJECT"]
    @region     = "us-central1"
    @seed       = SecureRandom.hex(8)
    @topics     = []
  end

  after do
    # Delete any Pub/Sub topics created during the test
    @topics.each &:delete
  end

  # Helper to get path to files in spec/resources/
  def resource path
    File.expand_path "resources/#{path}", __dir__
  end

  # Helper for creating PubSub topic
  def create_pubsub_topic topic_id
    pubsub = Google::Cloud::Pubsub.new project: @project_id
    topic  = pubsub.create_topic topic_id
    policy = topic.policy do |p|
      p.add "roles/pubsub.publisher",
            "serviceAccount:cloud-iot@system.gserviceaccount.com"
    end
    @topics << topic
    topic
  end

  example "Create / Delete registry" do
    # Setup scenario
    topic_name    = "A#{@seed}-create_delete_tester"
    registry_name = "A#{@seed}create_delete_test"
    topic         = create_pubsub_topic topic_name

    # Create a registry
    expect {
      $create_registry.call(
        project_id:   @project_id,
        location_id:  @region,
        registry_id:  registry_name,
        pubsub_topic: topic.name
      )
    }.to output(
      /Created registry/m
    ).to_stdout

    # Delete a registry
    expect {
      $delete_registry.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name
      )
    }.to output(
      /Deleted registry/m
    ).to_stdout
  end

  example "Set/Get IAM permissions" do
    # Setup scenario
    topic_name    = "A#{@seed}-iam_perm_test"
    registry_name = "A#{@seed}create_delete_test"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )

    # Test setting IAM permissions
    member = "group:dpebot@google.com"
    role = "roles/viewer"
    expect {
      $set_iam_policy.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        member:      member,
        role:        role
      )
      $get_iam_policy.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
      )
    }.to output(
      /Binding set:/m
    ).to_stdout

    # Clean up resources
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end

  example "Create/Delete unauth device" do
    # Setup scenario
    topic_name    = "A#{@seed}-iot_unauth_device"
    registry_name = "A#{@seed}create_delete_test"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )

    # Test setting IAM permissions
    device_id = "unauth_device"
    expect {
      $create_unauth_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id
      )
    }.to output(
      /Device:/m
    ).to_stdout
    expect {
      $delete_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id
      )
    }.to output(
      /Deleted device./m
    ).to_stdout

    # Clean up resources
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end

  example "Create/Delete ES device" do
    # Setup scenario
    topic_name    = "A#{@seed}-iot_es_device"
    registry_name = "A#{@seed}create_delete_test_es"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )

    # Test create / delete ES256 device
    device_id = "ec_device"
    expect {
      $create_es_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id,
        cert_path:   resource("ec_public.pem")
      )
    }.to output(
      /Device:/m
    ).to_stdout
    expect {
      $delete_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id
      )
    }.to output(
      /Deleted device./m
    ).to_stdout

    # Clean up resources
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end

  example "Create/Delete RSA device" do
    # Setup scenario
    topic_name    = "A#{@seed}-iot_rsa_device"
    registry_name = "A#{@seed}create_delete_test_rsa"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )

    # Test creating / removing device with RSA cert
    device_id = "ec_device"
    expect {
      $create_rsa_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id,
        cert_path:   resource("rsa_cert.pem")
      )
    }.to output(
      /Device:/m
    ).to_stdout
    expect {
      $delete_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id
      )
    }.to output(
      /Deleted device./m
    ).to_stdout

    # Clean up resources
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end

  example "List registries" do
    expect {
      $list_registries.call(
        project_id:  @project_id,
        location_id: @region,
      )
    }.to output(
      /Registries:/m
    ).to_stdout
  end

  example "Get unknown registry registry" do
    unknown_regname = "some_unknown_registry"
    expect {
      $get_registry.call(
        project_id:    @project_id,
        location_id:   @region,
        registry_id:   unknown_regname
      )
    }.to raise_error(
      /was not found/m
    )
  end

  example "Get unknown device" do
    unknown_regname = "some_unknown_registry"
    unknown_devname = "some_unknown_device"
    expect {
      $get_device.call(
        project_id:    @project_id,
        location_id:   @region,
        registry_id:   unknown_regname,
        device_id:     unknown_devname
      )
    }.to raise_error(
      /was not found/m
    )
  end

  example "List devices without registry" do
    unknown_regname = "some_unknown_registry"
    expect {
      $list_devices.call(
        project_id:    @project_id,
        location_id:   @region,
        registry_id:   unknown_regname,
      )
    }.to raise_error(
      /was not found/m
    )
  end

  example "Patches device" do
    # Setup scenario
    topic_name    = "A#{@seed}-iot_unauth_device_patches"
    registry_name = "A#{@seed}create_delete_test_patches"
    device_id     = "patches_unauth_device"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )
    $create_unauth_device.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name,
      device_id:   device_id
    )

    # Test patching device with ES cert
    expect {
      $patch_es_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id,
        cert_path:   resource("ec_public.pem")
      )
    }.to output(
      /Device: /m
    ).to_stdout

    # Clean up resources
    $delete_device.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name,
      device_id:   device_id
    )
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end

  example "Patchrsa device" do
    # Setup scenario
    topic_name    = "A#{@seed}-iot_unauth_device_patchrsa"
    registry_name = "A#{@seed}create_delete_test_patchrsa"
    device_id     = "patchrsa_unauth_device"
    topic         = create_pubsub_topic topic_name
    $create_registry.call(
      project_id:   @project_id,
      location_id:  @region,
      registry_id:  registry_name,
      pubsub_topic: topic.name
    )
    $create_unauth_device.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name,
      device_id:   device_id
    )

    # Test patch with RSA
    expect {
      $patch_rsa_device.call(
        project_id:  @project_id,
        location_id: @region,
        registry_id: registry_name,
        device_id:   device_id,
        cert_path:   resource("rsa_cert.pem")
      )
    }.to output(
      /Device: /m
    ).to_stdout

    # Clean up resources
    $delete_device.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name,
      device_id:   device_id
    )
    $delete_registry.call(
      project_id:  @project_id,
      location_id: @region,
      registry_id: registry_name
    )
  end
end
