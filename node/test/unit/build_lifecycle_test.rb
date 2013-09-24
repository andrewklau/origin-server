#!/usr/bin/env oo-ruby
#--
# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++
#
# Test the OpenShift application_container model
#
require_relative '../test_helper'
require 'fileutils'
require 'yaml'

module OpenShift
  ;
end

class BuildLifecycleTest < OpenShift::NodeTestCase

  def setup
    @config.stubs(:get).with("GEAR_BASE_DIR").returns("/tmp")

    # Set up the container
    @gear_uuid = "5503"
    @user_uid  = "5503"
    @app_name  = 'ApplicationContainerTestCase'
    @gear_name = @app_name
    @namespace = 'jwh201204301647'
    @gear_ip   = "127.0.0.1"

    @cartridge_model = mock()
    OpenShift::Runtime::V2CartridgeModel.stubs(:new).returns(@cartridge_model)

    @state = mock()
    OpenShift::Runtime::Utils::ApplicationState.stubs(:new).returns(@state)

    @hourglass = mock()
    @container = OpenShift::Runtime::ApplicationContainer.new(@gear_uuid, @gear_uuid, @user_uid,
        @app_name, @gear_uuid, @namespace, nil, nil, @hourglass)

    @frontend = mock('OpenShift::Runtime::FrontendHttpServer')
    OpenShift::Runtime::FrontendHttpServer.stubs(:new).returns(@frontend)
  end

  def test_pre_receive_default_builder
    @cartridge_model.expects(:builder_cartridge).returns(nil)

    @container.expects(:stop_gear).with(user_initiated: true, hot_deploy: nil, exclude_web_proxy: true, out: $stdout, err: $stderr)

    @container.pre_receive(out: $stdout, err: $stderr)
  end

  def test_post_receive_default_builder_nonscaled
    @cartridge_model.expects(:web_proxy).returns(nil)
    @container.expects(:child_gear_ssh_urls).never
    @container.expects(:sync_git_repo).never
    repository = mock()

    OpenShift::Runtime::ApplicationRepository.expects(:new).returns(repository)

    @cartridge_model.expects(:builder_cartridge).returns(nil)

    primary = mock()
    @cartridge_model.stubs(:primary_cartridge).returns(primary)

    @cartridge_model.expects(:do_control).with('pre-repo-archive',
                                                primary,
                                                out:                       $stdout,
                                                err:                       $stderr,
                                                pre_action_hooks_enabled:  false,
                                                post_action_hooks_enabled: false)

    deployment_datetime = "abc"
    @container.expects(:create_deployment_dir).returns(deployment_datetime)

    repository.expects(:archive).with(PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo'), 'master')
    git_sha1 = 'abcd1234'
    repository.expects(:get_sha1).with('master').returns(git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_sha1', git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_ref', 'master')

    @container.expects(:build).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:prepare).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:activate_gear).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)

    @container.expects(:distribute).never
    @container.expects(:activate).never

    @container.expects(:report_build_analytics)

    @container.post_receive(out: $stdout, err: $stderr)
  end

  def test_post_receive_default_builder_scaled
    proxy_cart = mock()
    @cartridge_model.expects(:web_proxy).returns(proxy_cart)
    gear_env = {a: 1, b: 2}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    proxy_ssh_urls = %w(uuid1@localhost uuid2@localhost uuid3@localhost)
    @container.expects(:child_gear_ssh_urls).with(:proxy).returns(proxy_ssh_urls)
    @container.expects(:sync_git_repo).with(proxy_ssh_urls, gear_env)

    repository = mock()

    OpenShift::Runtime::ApplicationRepository.expects(:new).returns(repository)

    @cartridge_model.expects(:builder_cartridge).returns(nil)

    primary = mock()
    @cartridge_model.stubs(:primary_cartridge).returns(primary)

    @cartridge_model.expects(:do_control).with('pre-repo-archive',
                                                primary,
                                                out:                       $stdout,
                                                err:                       $stderr,
                                                pre_action_hooks_enabled:  false,
                                                post_action_hooks_enabled: false)

    deployment_datetime = "abc"
    @container.expects(:create_deployment_dir).returns(deployment_datetime)

    repository.expects(:archive).with(PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo'), 'master')
    git_sha1 = 'abcd1234'
    repository.expects(:get_sha1).with('master').returns(git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_sha1', git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_ref', 'master')

    @container.expects(:build).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:prepare).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:activate_gear).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)

    @container.expects(:distribute).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:activate).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)

    @container.expects(:report_build_analytics)

    @container.post_receive(out: $stdout, err: $stderr)
  end

  def test_post_receive_default_unscaled_hot_deploy
    @cartridge_model.expects(:web_proxy).returns(nil)

    repository = mock()

    OpenShift::Runtime::ApplicationRepository.expects(:new).returns(repository)

    @cartridge_model.expects(:builder_cartridge).returns(nil)

    primary = mock()
    @cartridge_model.stubs(:primary_cartridge).returns(primary)

    @cartridge_model.expects(:do_control).with('pre-repo-archive',
                                                primary,
                                                out:                       $stdout,
                                                err:                       $stderr,
                                                pre_action_hooks_enabled:  false,
                                                post_action_hooks_enabled: false)

    deployment_datetime = "abc"
    @container.expects(:current_deployment_datetime).returns(deployment_datetime)
    @container.expects(:create_deployment_dir).never

    repository.expects(:archive).with(PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo'), 'master')
    git_sha1 = 'abcd1234'
    repository.expects(:get_sha1).with('master').returns(git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_sha1', git_sha1)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'git_ref', 'master')

    @container.expects(:build).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime, hot_deploy: true)
    @container.expects(:prepare).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime, hot_deploy: true)
    @container.expects(:activate_gear).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime, hot_deploy: true)

    @container.expects(:distribute).never
    @container.expects(:activate).never

    @container.expects(:report_build_analytics)

    @container.post_receive(out: $stdout, err: $stderr, hot_deploy: true)
  end

  def test_pre_receive_builder_cart
    builder = mock()
    @cartridge_model.expects(:builder_cartridge).returns(builder)

    @cartridge_model.expects(:do_control).with('pre-receive', builder, out: $stdout, err: $stderr)

    @container.pre_receive(out: $stdout, err: $stderr)
  end

  def test_post_receive_builder_cart
    @cartridge_model.expects(:web_proxy).returns(nil)

    builder = mock()
    @cartridge_model.expects(:builder_cartridge).returns(builder)

    @cartridge_model.expects(:do_control).with('post-receive', builder, out: $stdout, err: $stderr)

    @container.expects(:report_build_analytics)

    @container.post_receive(out: $stdout, err: $stderr)
  end

  def test_build_success
    @state.expects(:value=).with(OpenShift::Runtime::State::BUILDING)

    deployment_datetime = "abc"
    @container.expects(:update_dependencies_symlink).with(deployment_datetime)
    @container.expects(:update_build_dependencies_symlink).with(deployment_datetime)

    @container.expects(:deployments_to_keep).with(anything()).returns(2)

    primary = mock()
    @cartridge_model.expects(:primary_cartridge).returns(primary).times(3)

    env_overrides = {'OPENSHIFT_REPO_DIR' => PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo') + "/"}

    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary,
                                               pre_action_hooks_enabled:  false,
                                               post_action_hooks_enabled: false,
                                               out:                       $stdout,
                                               err:                       $stderr,
                                               env_overrides:             env_overrides)
                                          .returns('update-configuration|')

    @cartridge_model.expects(:do_control).with('pre-build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                          .returns('pre-build|')

    @cartridge_model.expects(:do_control).with('build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                           .returns('build')

    output = @container.build(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)

    assert_equal "update-configuration|pre-build|build", output
  end

  def test_build_failure_keep_one_deployment
    @state.expects(:value=).with(OpenShift::Runtime::State::BUILDING)

    deployment_datetime = "abc"
    @container.expects(:update_dependencies_symlink).with(deployment_datetime)
    @container.expects(:update_build_dependencies_symlink).with(deployment_datetime)

    @container.expects(:deployments_to_keep).with(anything()).returns(1)

    primary = mock()
    @cartridge_model.expects(:primary_cartridge).returns(primary).times(2)

    env_overrides = {'OPENSHIFT_REPO_DIR' => PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo') + "/"}

    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary,
                                               pre_action_hooks_enabled:  false,
                                               post_action_hooks_enabled: false,
                                               out:                       $stdout,
                                               err:                       $stderr,
                                               env_overrides:             env_overrides)
                                          .returns('update-configuration|')

    @cartridge_model.expects(:do_control).with('pre-build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                          .raises(OpenShift::Runtime::Utils::ShellExecutionException.new('foo'))

    @cartridge_model.expects(:do_control).with('build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                           .never()

    output = @container.build(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
  end

  def test_build_failure_keep_multiple_deployments
    @state.expects(:value=).with(OpenShift::Runtime::State::BUILDING)

    deployment_datetime = "abc"
    @container.expects(:update_dependencies_symlink).with(deployment_datetime)
    @container.expects(:update_build_dependencies_symlink).with(deployment_datetime)

    @container.expects(:deployments_to_keep).with(anything()).returns(2)

    primary = mock()
    @cartridge_model.expects(:primary_cartridge).returns(primary).times(2)

    env_overrides = {'OPENSHIFT_REPO_DIR' => PathUtils.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo') + "/"}

    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary,
                                               pre_action_hooks_enabled:  false,
                                               post_action_hooks_enabled: false,
                                               out:                       $stdout,
                                               err:                       $stderr,
                                               env_overrides:             env_overrides)
                                          .returns('update-configuration|')

    @cartridge_model.expects(:do_control).with('pre-build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                          .raises(OpenShift::Runtime::Utils::ShellExecutionException.new('foo'))

    @cartridge_model.expects(:do_control).with('build',
                                               primary,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks:      false,
                                               out:                      $stdout,
                                               err:                      $stderr,
                                               env_overrides:            env_overrides)
                                           .never()

    @container.expects(:start_gear).with(has_entries(user_initiated: true, hot_deploy: nil, exclude_web_proxy: true, out: $stdout, err: $stderr)).returns("bar")

    output = @container.build(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
  end

  def test_remote_deploy_nonscaled
    primary = mock()
    @cartridge_model.expects(:primary_cartridge).returns(primary)

    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary,
                                               pre_action_hooks_enabled:  false,
                                               post_action_hooks_enabled: false,
                                               out:                       $stdout,
                                               err:                       $stderr)
                                          .returns('')

    deployment_datetime = "now"

    [:prepare, :activate_gear].each do |method|
      @container.expects(method).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    end

    @cartridge_model.expects(:web_proxy).returns(nil)

    @container.remote_deploy(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
  end

  def test_remote_deploy_scaled
    primary = mock()
    @cartridge_model.expects(:primary_cartridge).returns(primary)

    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary,
                                               pre_action_hooks_enabled:  false,
                                               post_action_hooks_enabled: false,
                                               out:                       $stdout,
                                               err:                       $stderr)
                                          .returns('')

    deployment_datetime = "now"

    @container.expects(:prepare).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    @container.expects(:activate_gear).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    
    web_proxy = mock()
    @cartridge_model.expects(:web_proxy).returns(mock)

    [:distribute, :activate].each do |method|
      @container.expects(method).with(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
    end

    @container.remote_deploy(out: $stdout, err: $stderr, deployment_datetime: deployment_datetime)
  end

  def test_deploy
    @container.expects(:pre_receive).with(out: $stdout, err: $stderr, hot_deploy: true).returns(nil)
    @container.expects(:post_receive).with(out: $stdout, err: $stderr, hot_deploy: true, force_clean_build: false, ref: nil, report_deployments: nil).returns(nil)

    @container.deploy(out: $stdout, err: $stderr, hot_deploy: true, force_clean_build: false)
  end

  def test_configure_defaults
    cart_name = 'mock-0.1'
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:update_dependencies_symlink).with(latest_deployment_datetime)
    @container.expects(:update_build_dependencies_symlink).with(latest_deployment_datetime)
    @cartridge_model.expects(:configure).with(cart_name, nil, nil)
    @container.configure(cart_name)
  end

  def test_configure_with_args
    cart_name = 'mock-0.1'
    template_git_url = 'url'
    manifest = 'manifest'
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:update_dependencies_symlink).with(latest_deployment_datetime)
    @container.expects(:update_build_dependencies_symlink).with(latest_deployment_datetime)
    @cartridge_model.expects(:configure).with(cart_name, template_git_url, manifest)
    @container.configure(cart_name, template_git_url, manifest)
  end

  # new gear
  # no git template url specified
  # cartridge doesn't require build on install
  # not already DEPLOYED
  # not web proxy
  def test_post_configure_defaults
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(false)
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:read_deployment_metadata).with(latest_deployment_datetime, 'state').returns(nil)
    cartridge.expects(:web_proxy?).returns(false)
    @container.expects(:prepare).with(deployment_datetime: latest_deployment_datetime)
    @container.expects(:update_repo_symlink).with(latest_deployment_datetime)
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'state', 'DEPLOYED')
    git_sha1 = 'abcd1234'
    repository = mock()
    ::OpenShift::Runtime::ApplicationRepository.expects(:new).with(@container).returns(repository)
    repository.expects(:get_sha1).with('master').returns(git_sha1)
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'git_sha1', git_sha1)
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'git_ref', 'master')
    @container.expects(:set_rw_permission_R).with(File.join(@container.container_dir, 'app-deployments'))
    @container.expects(:reset_permission_R).with(File.join(@container.container_dir, 'app-deployments'))
    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name)
  end

  # new gear
  # empty git template url - should keep build from happening
  # not already DEPLOYED
  # not web proxy
  def test_post_configure_empty_clone_spec_prevents_build
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:read_deployment_metadata).with(latest_deployment_datetime, 'state').returns(nil)
    cartridge.expects(:web_proxy?).returns(false)
    @container.expects(:prepare).with(deployment_datetime: latest_deployment_datetime)
    @container.expects(:update_repo_symlink).with(latest_deployment_datetime)
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'state', 'DEPLOYED')
    repository = mock()
    ::OpenShift::Runtime::ApplicationRepository.expects(:new).with(@container).returns(repository)
    repository.expects(:get_sha1).with('master').returns('')
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'git_sha1', '').never
    @container.expects(:write_deployment_metadata).with(latest_deployment_datetime, 'git_ref', 'master').never
    @container.expects(:set_rw_permission_R).with(File.join(@container.container_dir, 'app-deployments'))
    @container.expects(:reset_permission_R).with(File.join(@container.container_dir, 'app-deployments'))
    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name, 'empty')
  end

  # new gear
  # cartridge requires build on install
  def test_post_configure_cartridge_build_on_install_does_build
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(true)
    cartridge.expects(:buildable?).returns(true)
    gear_env = {a: 1, b: 2}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    cgroups = mock()
    OpenShift::Runtime::Utils::Cgroups.expects(:new).returns(cgroups)
    cgroups.expects(:boost).yields()
    @hourglass.expects(:remaining).twice.returns(100, 50)
    OpenShift::Runtime::Utils.expects(:oo_spawn).with("gear prereceive >> /tmp/initial-build.log 2>&1",
                                                      env:                 gear_env,
                                                      chdir:               @container.container_dir,
                                                      uid:                 @container.uid,
                                                      timeout:             100,
                                                      expected_exitstatus: 0)

    OpenShift::Runtime::Utils.expects(:oo_spawn).with("gear postreceive >> /tmp/initial-build.log 2>&1",
                                                      env:                 gear_env,
                                                      chdir:               @container.container_dir,
                                                      uid:                 @container.uid,
                                                      timeout:             50,
                                                      expected_exitstatus: 0)

    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name)
  end

  # new gear
  # cartridge does NOT require build on install
  # template git url passed in
  def test_post_configure_template_build_url_does_build
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(false)
    cartridge.expects(:buildable?).returns(true)

    gear_env = {a: 1, b: 2}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    cgroups = mock()
    OpenShift::Runtime::Utils::Cgroups.expects(:new).returns(cgroups)
    cgroups.expects(:boost).yields()
    @hourglass.expects(:remaining).twice.returns(100, 50)
    OpenShift::Runtime::Utils.expects(:oo_spawn).with("gear prereceive >> /tmp/initial-build.log 2>&1",
                                                 env:                 gear_env,
                                                 chdir:               @container.container_dir,
                                                 uid:                 @container.uid,
                                                 timeout:             100,
                                                 expected_exitstatus: 0)

    OpenShift::Runtime::Utils.expects(:oo_spawn).with("gear postreceive >> /tmp/initial-build.log 2>&1",
                                                 env:                 gear_env,
                                                 chdir:               @container.container_dir,
                                                 uid:                 @container.uid,
                                                 timeout:             50,
                                                 expected_exitstatus: 0)

    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name, 'url')
  end

  # new gear
  # cartridge does NOT require build on install
  # template git url passed in
  def test_post_configure_rescues_build_exception
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(false)
    cartridge.expects(:buildable?).returns(true)
    gear_env = {a: 1, b: 2}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    cgroups = mock()
    OpenShift::Runtime::Utils::Cgroups.expects(:new).returns(cgroups)
    cgroups.expects(:boost).yields()
    @hourglass.expects(:remaining).twice.returns(100, 50)
    OpenShift::Runtime::Utils.expects(:oo_spawn).with("gear prereceive >> /tmp/initial-build.log 2>&1",
                                                      env:                 gear_env,
                                                      chdir:               @container.container_dir,
                                                      uid:                 @container.uid,
                                                      timeout:             100,
                                                      expected_exitstatus: 0)
                                                .raises(OpenShift::Runtime::Utils::ShellExecutionException.new('my error', 1))

    OpenShift::Runtime::Utils.expects(:oo_spawn).with("tail -c 10240 /tmp/initial-build.log 2>&1",
                                                      env:                 gear_env,
                                                      chdir:               @container.container_dir,
                                                      uid:                 @container.uid,
                                                      timeout:             50)
                                                .returns("some output")

    assert_raises(RuntimeError, "CLIENT_ERROR: The initial build for the application failed: my error\nCLIENT_ERROR: \nCLIENT_ERROR: .Last 10 kB of build output:\nCLIENT_ERROR: some output\n") { @container.post_configure(cart_name, 'url') }
  end

  # new gear
  # no git template url specified
  # cartridge doesn't require build on install
  # already DEPLOYED
  def test_post_configure_already_deployed
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(false)
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:read_deployment_metadata).with(latest_deployment_datetime, 'state').returns('DEPLOYED')
    @container.expects(:prepare).never
    @container.expects(:update_repo_symlink).never
    @container.expects(:write_deployment_metadata).never
    @container.expects(:set_rw_permission_R).never
    @container.expects(:reset_permission_R).never
    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name)
  end

  # new gear
  # no git template url specified
  # cartridge doesn't require build on install
  # not DEPLOYED
  # web proxy
  def test_post_configure_web_proxy
    cart_name = 'mock-0.1'
    cartridge = mock()
    @cartridge_model.expects(:get_cartridge).with(cart_name).returns(cartridge)
    cartridge.expects(:install_build_required).returns(false)
    latest_deployment_datetime = "now"
    @container.expects(:latest_deployment_datetime).returns(latest_deployment_datetime)
    @container.expects(:read_deployment_metadata).with(latest_deployment_datetime, 'state').returns(nil)
    cartridge.expects(:web_proxy?).returns(true)
    @container.expects(:prepare).never
    @container.expects(:update_repo_symlink).never
    @container.expects(:write_deployment_metadata).never
    @container.expects(:set_rw_permission_R).never
    @container.expects(:reset_permission_R).never
    @cartridge_model.expects(:post_configure).with(cart_name)

    @container.post_configure(cart_name)
  end

  def test_prepare_without_file_success
    deployment_datetime = 'now'

    gear_env = {}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    @cartridge_model.expects(:do_action_hook).with('prepare',
                                                   {'OPENSHIFT_REPO_DIR' => File.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo')},
                                                   {deployment_datetime: deployment_datetime})
                                             .returns("output from prepare hook\n")

    deployment_id = 'abcd1234'  
    @container.expects(:calculate_deployment_id).with(deployment_datetime).returns(deployment_id)
    @container.expects(:link_deployment_id).with(deployment_datetime, deployment_id)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'id', deployment_id)

    prepare_options = {deployment_datetime: deployment_datetime}
    output = @container.prepare(prepare_options)

    assert_equal deployment_id, prepare_options[:deployment_id]
    assert_equal "output from prepare hook\nPrepared deployment artifacts in #{File.join(@container.container_dir, 'app-deployments', deployment_datetime)}\nDeployment id is #{deployment_id}", output
  end

  def test_prepare_without_file_failure
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns({})

    deployment_datetime = 'now'
    @cartridge_model.expects(:do_action_hook).with('prepare',
                                                   {'OPENSHIFT_REPO_DIR' => File.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo')},
                                                   {deployment_datetime: deployment_datetime})
                                             .returns("output from prepare hook\n")

    deployment_id = 'abcd1234'  
    @container.expects(:calculate_deployment_id).with(deployment_datetime).returns(deployment_id)
    @container.expects(:link_deployment_id).with(deployment_datetime, deployment_id)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'id', deployment_id).raises(IOError.new('msg'))
    @container.expects(:unlink_deployment_id).with(deployment_id)

    prepare_options = {deployment_datetime: deployment_datetime}
    output = @container.prepare(prepare_options)

    assert_nil prepare_options[:deployment_id]
  end

  def test_prepare_with_valid_file
    deployment_datetime = 'now'
    filename = 'test.tar.gz'
    file_path = File.join(@container.container_dir, 'app-archives', filename)
    prepare_options = {deployment_datetime: deployment_datetime, file: filename}

    gear_env = {}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    @container.expects(:extract_deployment_archive).with(gear_env, filename, PathUtils.join(@container.container_dir, 'app-deployments', 'now'))
    gear_env_with_repo_dir_override = {'OPENSHIFT_REPO_DIR' => File.join(@container.container_dir, 'app-deployments', deployment_datetime, 'repo')}
    @cartridge_model.expects(:do_action_hook).with('prepare',
                                                   gear_env_with_repo_dir_override,
                                                   prepare_options)
                                             .returns("output from prepare hook\n")

    deployment_id = 'abcd1234'  
    @container.expects(:calculate_deployment_id).with(deployment_datetime).returns(deployment_id)

    FileUtils.expects(:cd).with(File.join(@container.container_dir, 'app-deployments', 'by-id')).yields
    FileUtils.expects(:ln_s).with(File.join('..', deployment_datetime), deployment_id)
    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'id', deployment_id)

    output = @container.prepare(prepare_options)

    assert_equal deployment_id, prepare_options[:deployment_id]
    assert_equal "output from prepare hook\nPrepared deployment artifacts in #{File.join(@container.container_dir, 'app-deployments', deployment_datetime)}\nDeployment id is #{deployment_id}", output
  end

  def test_prepare_with_missing_file
    deployment_datetime = 'now'
    filename = 'test.tar.gz'

    gear_env = {}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    @container.expects(:extract_deployment_archive).with(gear_env, filename, PathUtils.join(@container.container_dir, 'app-deployments', 'now')).raises(RuntimeError.new('msg'))

    prepare_options = {deployment_datetime: deployment_datetime, file: filename}
    assert_raises(RuntimeError, 'msg') { @container.prepare(prepare_options) }
  end

  def test_child_gear_ssh_urls_no_web_proxy
    @cartridge_model.expects(:web_proxy).returns(nil)
    assert_empty @container.child_gear_ssh_urls
  end

  def test_child_gear_ssh_urls_web_proxy
    @cartridge_model.expects(:web_proxy).returns(1)

    gear_registry = mock()
    @container.expects(:gear_registry).returns(gear_registry)

    self_entry = mock()

    other_entry = mock()
    other_entry.expects(:proxy_hostname).returns('localhost')

    other_entry2 = mock()
    other_entry2.expects(:proxy_hostname).returns('localhost')

    entries = {
      :web => {
        @container.uuid => self_entry,
        '5504' => other_entry,
        '5505' => other_entry2
      }
    }

    gear_registry.expects(:entries).returns(entries)

    urls = @container.child_gear_ssh_urls
    assert_equal 2, urls.size
    assert_includes urls, '5504@localhost'
    assert_includes urls, '5505@localhost'
  end

  def test_child_gear_ssh_urls_uses_specified_type
    @cartridge_model.expects(:web_proxy).returns(1)
    gear_registry = mock()
    @container.expects(:gear_registry).returns(gear_registry)

    self_entry = mock()

    other_entry = mock()

    other_entry2 = mock()
    other_entry2.expects(:proxy_hostname).returns('localhost')

    entries = {
      :proxy => {
        @container.uuid => self_entry,
        '5505' => other_entry2
      },
      :web => {
        @container.uuid => self_entry,
        '5504' => other_entry,
        '5505' => other_entry2
      }
    }

    gear_registry.expects(:entries).returns(entries)

    urls = @container.child_gear_ssh_urls(:proxy)
    assert_equal 1, urls.size
    assert_includes urls, '5505@localhost'
  end

  def test_distribute_no_child_gears
    @container.expects(:child_gear_ssh_urls).returns([])

    @container.expects(:get_deployment_datetime_for_deployment_id).never
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).never
    @container.expects(:run_in_container_context).never

    result = @container.distribute({ deployment_id: 123})

    assert_equal :success, result[:status]
    assert_equal 0, result[:gear_results].size
  end

  def test_distribute_no_deployment_id
    @container.expects(:get_deployment_datetime_for_deployment_id).never

    assert_raise(ArgumentError) do
      @container.distribute({})
    end
  end

  def test_distribute_child_gears_success
    deployment_id = 'abcd1234'
    deployment_datetime = 'now'
    deployment_dir = File.join(@container.container_dir, 'app-deployments', deployment_datetime)
    
    gears = %w(1234@localhost 2345@localhost)
    @container.expects(:child_gear_ssh_urls).returns(gears)

    @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)
    gear_env = {'key' => 'value'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    gears.each do |g|
      @container.expects(:distribute_to_gear).with(g, gear_env, deployment_dir, deployment_datetime, deployment_id).returns({ status: :success })
    end

    result = @container.distribute(deployment_id: deployment_id)

    assert_equal :success, result[:status]
    assert_equal 2, result[:gear_results].size
    assert_equal :success, result[:gear_results]['1234'][:status]
    assert_equal :success, result[:gear_results]['2345'][:status]
  end

  def test_distribute_failure
    deployment_id = 'abcd1234'
    deployment_datetime = 'now'
    deployment_dir = File.join(@container.container_dir, 'app-deployments', deployment_datetime)
    
    gears = %w(1234@localhost 2345@localhost)
    @container.expects(:child_gear_ssh_urls).returns(gears)

    @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)
    gear_env = {'key' => 'value'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    @container.expects(:distribute_to_gear).with('1234@localhost', gear_env, deployment_dir, deployment_datetime, deployment_id).returns({ status: :success })
    @container.expects(:distribute_to_gear).with('2345@localhost', gear_env, deployment_dir, deployment_datetime, deployment_id).returns({ status: :failure })

    result = @container.distribute(deployment_id: deployment_id)

    assert_equal :failure, result[:status]
    assert_equal 2, result[:gear_results].size
    assert_equal :success, result[:gear_results]['1234'][:status]
    assert_equal :failure, result[:gear_results]['2345'][:status]
  end

  def test_distribute_specified_gears
    deployment_id = 'abcd1234'
    deployment_datetime = 'now'
    deployment_dir = File.join(@container.container_dir, 'app-deployments', deployment_datetime)

    gears = %w(1234@localhost 2345@localhost)

    @container.expects(:child_gear_ssh_urls).never
    @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)
    gear_env = {'key' => 'value'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    gears.each do |g|
      @container.expects(:distribute_to_gear).with(g, gear_env, deployment_dir, deployment_datetime, deployment_id).returns({ status: :success })
    end

    result = @container.distribute(gears: gears, deployment_id: deployment_id)

    assert_equal :success, result[:status]
    assert_equal 2, result[:gear_results].size
    assert_equal :success, result[:gear_results]['1234'][:status]
    assert_equal :success, result[:gear_results]['2345'][:status]
  end

  def test_distribute_to_gear_success
    gear = mock()
    gear_env = mock()
    deployment_dir = mock()
    deployment_datetime = mock()
    deployment_id = mock()

    @container.expects(:attempt_distribute_to_gear).with(gear, gear_env, deployment_dir, deployment_datetime, deployment_id).once()

    result = @container.distribute_to_gear(gear, gear_env, deployment_dir, deployment_datetime, deployment_id)

    assert_equal :success, result[:status]
  end

  def test_distribute_to_gear_retry_success
    gear = mock()
    gear_env = mock()
    deployment_dir = mock()
    deployment_datetime = mock()
    deployment_id = mock()

    results = [ lambda { raise ::OpenShift::Runtime::Utils::ShellExecutionException.new('msg') }, lambda { return true } ]
    @container.expects(:attempt_distribute_to_gear).with(gear, gear_env, deployment_dir, deployment_datetime, deployment_id).returns { lambda { results.shift.call }}

    result = @container.distribute_to_gear(gear, gear_env, deployment_dir, deployment_datetime, deployment_id)

    assert_equal :success, result[:status]
  end

  def test_distribute_to_gear_retry_failure
    gear = mock()
    gear_env = mock()
    deployment_dir = mock()
    deployment_datetime = mock()
    deployment_id = mock()

    exception = ::OpenShift::Runtime::Utils::ShellExecutionException.new('msg')
    @container.expects(:attempt_distribute_to_gear).with(gear, gear_env, deployment_dir, deployment_datetime, deployment_id).raises(exception).times(3)

    result = @container.distribute_to_gear(gear, gear_env, deployment_dir, deployment_datetime, deployment_id)

    assert_equal :failure, result[:status]
  end

  def test_activate_not_elected_proxy
    gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => '123-ns.example.com'}

    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    @container.expects(:child_gear_ssh_urls).never
    @container.expects(:run_in_container_context).never

    result = @container.activate(deployment_id: "123")

    assert_equal :success, result[:status]
    assert_equal 0, result[:gear_results].size
  end

  def test_activate_no_child_gears
    gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}

    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
    @container.expects(:child_gear_ssh_urls).returns([])
    @container.expects(:run_in_container_context).never

    result = @container.activate(deployment_id: "123")

    assert_equal :success, result[:status]
    assert_equal 0, result[:gear_results].size
  end

  def test_activate_success
    deployment_id = 'abcd1234'

    gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    gears = %w(1234@localhost 2345@localhost)
    @container.expects(:child_gear_ssh_urls).returns(gears)

    @container.expects(:activate_remote_gear).with('1234@localhost', gear_env, has_key(:deployment_id)).returns(gear_uuid: '1234', status: :success, errors: [], messages: [])
    @container.expects(:activate_remote_gear).with('2345@localhost', gear_env, has_key(:deployment_id)).returns(gear_uuid: '2345', status: :success, errors: [], messages: [])
    
    result = @container.activate(deployment_id: deployment_id)

    assert_equal :success, result[:status]
    assert_equal 2, result[:gear_results].size
  end

  def test_activate_failure
    deployment_id = 'abcd1234'

    gears = %w(1234@localhost 2345@localhost)
    @container.expects(:child_gear_ssh_urls).returns(gears)

    gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    @container.expects(:activate_remote_gear).with('1234@localhost', gear_env, has_key(:deployment_id)).returns(gear_uuid: '1234', status: :success, errors: [], messages: [])
    @container.expects(:activate_remote_gear).with('2345@localhost', gear_env, has_key(:deployment_id)).returns(gear_uuid: '2345', status: :failure, errors: [], messages: [])

    result = @container.activate(deployment_id: deployment_id)

    assert_equal :failure, result[:status]
    assert_equal 2, result[:gear_results].size
  end

  def test_activate_remote_gear_success
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --no-hot-deploy",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .returns('out')

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :success, result[:status]
  end

  def test_activate_remote_gear_proxy_disable_fails
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :failure, messages: [], errors: [])

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --no-hot-deploy",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .never

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .never

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :failure, result[:status]
  end

  def test_activate_remote_gear_activation_fails
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --no-hot-deploy",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .raises(::OpenShift::Runtime::Utils::ShellExecutionException.new('msg'))

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .never

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :failure, result[:status]
  end

  def test_activate_remote_gear_proxy_enable_fails
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --no-hot-deploy",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .returns('out')

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :failure, messages: [], errors: [])

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :failure, result[:status]
  end

  def test_activate_remote_gear_hot_deploy
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id, hot_deploy: true }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .never

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --hot-deploy",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .returns('out')

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .never

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :success, result[:status]
  end

  def test_activate_remote_gear_init
    deployment_id = 'abcd1234'
    g = "1234@localhost"
    gear_uuid = "1234"
    gear_env = {}
    options = { deployment_id: deployment_id, init: true }

    @container.expects(:update_proxy_status)
              .with(action: :disable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear activate #{deployment_id} --no-hot-deploy --init",
                                                       env: gear_env,
                                                       expected_exitstatus: 0)
                                                 .returns('out')

    @container.expects(:update_proxy_status)
              .with(action: :enable, gear_uuid: gear_uuid, persist: false)
              .returns(status: :success, messages: [], errors: [])

    result = @container.activate_remote_gear(g, gear_env, options)

    assert_equal :success, result[:status]
  end

  # options
  # gear_started
  # init
  # scalable
  def do_activate_test(options)
    deployment_id = 'abcd1234'
    deployment_datetime = 'now'
    deployment_dir = File.join(@container.container_dir, 'app-deployments', deployment_datetime)
    activate_options = {deployment_id: deployment_id, hot_deploy: true}

    @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)

    gear_env = {'key' => 'value'}
    OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

    stop_output = ''
    if options[:gear_started]
      @container.state.expects(:value).returns(::OpenShift::Runtime::State::STARTED)
      @container.expects(:stop_gear).with(activate_options.merge(exclude_web_proxy: true)).returns("stop\n")
      stop_output = "stop\n"
    else
      @container.state.expects(:value).returns(::OpenShift::Runtime::State::STOPPED)
      @container.expects(:stop_gear).never
    end

    @container.expects(:update_repo_symlink).with(deployment_datetime)
    @container.expects(:update_dependencies_symlink).with(deployment_datetime)
    primary_cartridge = mock()
    @cartridge_model.expects(:primary_cartridge).at_least(3).returns(primary_cartridge)
    @cartridge_model.expects(:do_control).with('update-configuration',
                                               primary_cartridge,
                                               pre_action_hooks_enabled: false,
                                               post_action_hooks_enabled: false,
                                               out: nil,
                                               err: nil)

    @container.expects(:start_gear).with(secondary_only: true,
                                         user_initiated: true,
                                         exclude_web_proxy: true,
                                         hot_deploy: true,
                                         out: nil,
                                         err: nil)
                                   .returns("start secondary\n")

    @container.state.expects(:value=).with(::OpenShift::Runtime::State::DEPLOYING)

    @cartridge_model.expects(:do_control).with('deploy',
                                               primary_cartridge,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks: false,
                                               out: nil,
                                               err:nil)
                                         .returns("deploy\n")

    @container.expects(:start_gear).with(primary_only: true,
                                         user_initiated: true,
                                         exclude_web_proxy: true,
                                         hot_deploy: true,
                                         out: nil,
                                         err: nil)
                                   .returns("start primary\n")

    @cartridge_model.expects(:do_control).with('post-deploy',
                                               primary_cartridge,
                                               pre_action_hooks_enabled: false,
                                               prefix_action_hooks: false,
                                               out: nil,
                                               err:nil)
                                         .returns("post-deploy\n")

    if options[:init]
      activate_options.merge!(init: true)
      primary_cartridge_directory = 'primarycartdir'
      primary_cartridge.expects(:directory).returns(primary_cartridge_directory)
      primary_cart_env_dir = File.join(@container.container_dir, primary_cartridge_directory, 'env')
      primary_cart_env = {'OPENSHIFT_XYZ_IDENT' => 'redhat:mock:0.1:0.1'}
      ::OpenShift::Runtime::Utils::Environ.expects(:load).with(primary_cart_env_dir).returns(primary_cart_env)

      @cartridge_model.expects(:post_install).with(primary_cartridge,
                                                   '0.1',
                                                   out: nil,
                                                   err: nil)
    else
      primary_cartridge.expects(:directory).never
      ::OpenShift::Runtime::Utils::Environ.expects(:load).never
      @cartridge_model.expects(:post_install).never
    end

    @container.expects(:write_deployment_metadata).with(deployment_datetime, 'state', 'DEPLOYED')
    @container.expects(:clean_up_deployments_before).with(deployment_datetime)

    web_proxy = options[:scalable] ? mock() : nil
    @cartridge_model.expects(:web_proxy).returns(web_proxy)
    enable_server_expectation = @container.expects(:update_proxy_status).with(cartridge: web_proxy,
                                                                              action: :enable,
                                                                              gear_uuid: @container.uuid,
                                                                              persist: false)
    enable_server_expectation.never unless web_proxy

    output = @container.activate(activate_options)

    assert_equal "#{stop_output}Starting application ApplicationContainerTestCase\nstart secondary\ndeploy\nstart primary\npost-deploy\n", output
  end

  # def test_activate_stops_started_gear
  #   do_activate_test(gear_started: true)
  # end

  # def test_activate_doesnt_call_stop_if_already_stopped
  #   do_activate_test(gear_started: false)
  # end

  # def test_activate_with_init_option
  #   do_activate_test(init: true)
  # end

  # def test_activate_enables_local_gear_if_scalable
  #   do_activate_test(scalable: true)
  # end

  # def test_rollback_many_app_dns_different_from_gear_dns
  #   gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => '123-ns.example.com'}
  #   OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
  #   @container.expects(:child_gear_ssh_urls).never
  #   @container.expects(:run_in_container_context).never
  #   @container.rollback_many()
  # end

  # def test_rollback_many_no_child_gears
  #   gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}
  #   OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)
  #   @container.expects(:child_gear_ssh_urls).returns([])
  #   @container.expects(:run_in_container_context).never
  #   @container.rollback_many()
  # end

  # def test_rollback_many_defaults_to_child_gears
  #   gears = %w(1234@localhost 2345@localhost)
  #   @container.expects(:child_gear_ssh_urls).returns(gears)

  #   gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}
  #   OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

  #   web_proxy = mock()
  #   @cartridge_model.expects(:web_proxy).returns(web_proxy)

  #   gears.each do |g|
  #     gear_uuid = g.split('@')[0]

  #     @container.expects(:parallel_update_proxy_status).with(action: :disable, gear_uuid: gear_uuid, persist: false)

  #     @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear rollback",
  #                                                        env: gear_env,
  #                                                        expected_exitstatus: 0)
  #                                                  .returns("out from #{g}\n")

  #     @container.expects(:parallel_update_proxy_status).with(action: :enable, gear_uuid: gear_uuid, persist: false)
  #   end

  #   output = @container.rollback_many()

  #   assert_equal "Rolling back gear 1234\nout from 1234@localhost\nRolling back gear 2345\nout from 2345@localhost\n", output
  # end

  # def test_rollback_many_uses_specified_gears
  #   gear_env = {'OPENSHIFT_APP_DNS' => 'app-ns.example.com', 'OPENSHIFT_GEAR_DNS' => 'app-ns.example.com'}
  #   OpenShift::Runtime::Utils::Environ.expects(:for_gear).with(@container.container_dir).returns(gear_env)

  #   gears = %w(1234@localhost 2345@localhost)
  #   @container.expects(:child_gear_ssh_urls).never

  #   web_proxy = mock()
  #   @cartridge_model.expects(:web_proxy).returns(web_proxy)

  #   gears.each do |g|
  #     gear_uuid = g.split('@')[0]

  #     @container.expects(:parallel_update_proxy_status).with(action: :disable, gear_uuid: gear_uuid, persist: false)

  #     @container.expects(:run_in_container_context).with("/usr/bin/oo-ssh #{g} gear rollback",
  #                                                        env: gear_env,
  #                                                        expected_exitstatus: 0)
  #                                                  .returns("out from #{g}\n")

  #     @container.expects(:parallel_update_proxy_status).with(action: :enable, gear_uuid: gear_uuid, persist: false)
  #   end

  #   output = @container.rollback_many(gears: gears)

  #   assert_equal "Rolling back gear 1234\nout from 1234@localhost\nRolling back gear 2345\nout from 2345@localhost\n", output
  # end

  # def test_rollback_default
  #   deployment_id = 'abcd1234'
  #   deployment_datetime1 = '2013-08-16_13-36-36.880' # deployed
  #   deployment_datetime2 = '2013-08-16_14-36-36.880' # never deployed
  #   deployment_datetime3 = '2013-08-16_15-36-36.881' # active
  #   deployment_datetime4 = '2013-08-17_15-36-36.881' # deployed at some point, but not currently active
  #   deployments_dir = File.join(@container.container_dir, 'app-deployments')
  #   rollback_options = {'a' => 'b'}

  #   @container.expects(:current_deployment_datetime).returns(deployment_datetime3)
  #   Dir.expects(:[]).with("#{deployments_dir}/*").returns([deployment_datetime2, deployment_datetime3, deployment_datetime1, 'by-id', deployment_datetime4])
  #   @container.expects(:read_deployment_metadata).with(deployment_datetime2, 'state').returns(nil)
  #   @container.expects(:read_deployment_metadata).with(deployment_datetime1, 'state').returns("DEPLOYED\n")

  #   @container.expects(:read_deployment_metadata).with(deployment_datetime1, 'id').returns("a1b2c3d4\n")
  #   @container.expects(:activate).with(rollback_options.merge(deployment_id: 'a1b2c3d4')).returns("activate output\n")

  #   output = @container.rollback(rollback_options)
  #   assert_equal "Looking up previous deployment\nRolling back to deployment ID a1b2c3d4\nactivate output\n", output
  # end

  # def test_rollback_raises_when_no_previous_deployment_exists
  #   deployment_datetime = '2013-08-16_15-36-36.881'
  #   @container.expects(:current_deployment_datetime).returns(deployment_datetime)
  #   deployments_dir = File.join(@container.container_dir, 'app-deployments')
  #   Dir.expects(:[]).with("#{deployments_dir}/*").returns([deployment_datetime, 'by-id'])

  #   assert_raises(RuntimeError, 'No prior deployments exist - unable to roll back') { @container.rollback }
  # end

  # def test_rollback_raises_when_specified_deployment_does_not_exist
  #   deployment_id = 'abc'
  #   @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(nil)
  #   assert_raises(RuntimeError, "Deployment ID '#{deployment_id}' does not exist") { @container.rollback(deployment_id: deployment_id) }
  # end

  # def test_rollback_raises_when_specified_deployment_was_never_deployed
  #   deployment_datetime = '2013-08-16_15-36-36.881'
  #   deployment_id = 'a1b2c3d4'

  #   @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)
  #   @container.expects(:read_deployment_metadata).with(deployment_datetime, 'state').returns(nil)
  #   assert_raises(RuntimeError, "Deployment ID '#{deployment_id}' was never deployed - unable to roll back") { @container.rollback(deployment_id: deployment_id) }
  # end

  # def test_rollback_for_specified_deployment_id
  #   deployment_datetime = '2013-08-16_15-36-36.881'
  #   deployment_id = 'a1b2c3d4'
  #   rollback_options = {'a' => 'b', :deployment_id => deployment_id}

  #   @container.expects(:get_deployment_datetime_for_deployment_id).with(deployment_id).returns(deployment_datetime)
  #   @container.expects(:read_deployment_metadata).with(deployment_datetime, 'state').returns("DEPLOYED\n")
  #   @container.expects(:activate).with(rollback_options).returns("activate output\n")
  #   output = @container.rollback(rollback_options)
  #   assert_equal "Rolling back to deployment ID a1b2c3d4\nactivate output\n", output
  # end
end