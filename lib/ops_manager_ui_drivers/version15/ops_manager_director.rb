require 'ops_manager_ui_drivers/version15/settings'

module OpsManagerUiDrivers
  module Version15
    class OpsManagerDirector
      def initialize(browser:, iaas_configuration: Version15::IaasConfiguration.new(browser: browser))
        @browser            = browser
        @iaas_configuration = iaas_configuration
      end

      def configure_microbosh(test_settings)
        configure_iaas(test_settings)

        config_director(test_settings.ops_manager)

        add_availability_zones(test_settings.iaas_type, test_settings.ops_manager.availability_zones)

        assign_availability_zone(test_settings.iaas_type, test_settings.ops_manager.availability_zones)

        add_networks(test_settings)

        assign_networks(test_settings.ops_manager)

        customize_resource_config(test_settings.ops_manager.resource_config)
      end

      def configure_iaas(test_settings)
        iaas_configuration.open_form
        iaas_settings = Settings.for(test_settings)
        iaas_settings.fields.each do |name, value|
          iaas_configuration.set_field(name, value)
        end
        iaas_configuration.save_form
      end

      def add_availability_zones(iaas_type, iaas_availability_zones)
        case iaas_type
          when OpsManagerUiDrivers::AWS_IAAS_TYPE, OpsManagerUiDrivers::OPENSTACK_IAAS_TYPE
            return unless iaas_availability_zones
            availability_zones.add_single_az(iaas_availability_zones.first['iaas_identifier'])
          when OpsManagerUiDrivers::VSPHERE_IAAS_TYPE
            iaas_availability_zones && iaas_availability_zones.each do |az|
              availability_zones.add_az('name' => az['name'], 'cluster' => az['cluster'], 'resource_pool' => az['resource_pool'])
            end
        end
      end

      def add_networks(test_settings)
        iaas_networks = test_settings.ops_manager.networks

        case test_settings.iaas_type
          when OpsManagerUiDrivers::AWS_IAAS_TYPE, OpsManagerUiDrivers::OPENSTACK_IAAS_TYPE
            first_network = iaas_networks.first
            browser.click_on 'show-network-action'
            browser.fill_in 'network[networks][][name]', with: first_network['name']
            browser.fill_in 'network[networks][][iaas_network_identifier]', with: first_network['identifier']
            browser.fill_in 'network[networks][][subnet]', with: first_network['subnet']
            browser.fill_in 'network[networks][][reserved_ip_ranges]', with: first_network['reserved_ips']
            browser.fill_in 'network[networks][][dns]', with: first_network['dns']
            browser.fill_in 'network[networks][][gateway]', with: first_network['gateway']
            browser.click_on 'Save'
            flash_errors = browser.all('.flash-message.error ul.message li').to_a
            flash_errors.reject! { |node| node.text =~ /cannot reach gateway/i }

            if (flash_errors.length > 0)
              fail flash_errors.collect(&:text).inspect
            end
          else
            iaas_networks && iaas_networks.each do |network|
              networks.add_network(
                name:                    network['name'],
                iaas_network_identifier: network['identifier'],
                subnet:                  network['subnet'],
                reserved_ip_ranges:      network['reserved_ips'],
                dns:                     network['dns'],
                gateway:                 network['gateway'],
              )
            end
        end
      end

      def config_director(ops_manager)
        browser.click_on 'Director Config'
        browser.fill_in('director_configuration[ntp_servers_string]', with: ops_manager.ntp_servers)
        browser.check('Enable VM Resurrector Plugin') if ops_manager.resurrector_enabled

        s3_blobstore = ops_manager.s3_blobstore
        if s3_blobstore
          browser.choose('S3 Compatible Blobstore')
          browser.fill_in('director_configuration[s3_blobstore_options][endpoint]', with: s3_blobstore.endpoint)
          browser.fill_in('director_configuration[s3_blobstore_options][bucket_name]', with: s3_blobstore.bucket_name)
          browser.fill_in('director_configuration[s3_blobstore_options][access_key]', with: s3_blobstore.access_key_id)
          browser.fill_in('director_configuration[s3_blobstore_options][secret_key]', with: s3_blobstore.secret_access_key)
        end

        mysql = ops_manager.mysql
        if mysql
          browser.choose('External MySQL Database')
          browser.fill_in('director_configuration[external_database_options][host]', with: mysql.host)
          browser.fill_in('director_configuration[external_database_options][port]', with: mysql.port)
          browser.fill_in('director_configuration[external_database_options][user]', with: mysql.user)
          browser.fill_in('director_configuration[external_database_options][password]', with: mysql.password)
          browser.fill_in('director_configuration[external_database_options][database]', with: mysql.dbname)
        end

        browser.click_on 'Save'
      end

      def assign_availability_zone(iaas_type, iaas_availability_zones)
        return unless iaas_availability_zones
        case iaas_type
          when OpsManagerUiDrivers::AWS_IAAS_TYPE, OpsManagerUiDrivers::OPENSTACK_IAAS_TYPE
            browser.click_on 'Assign Availability Zones'
            browser.select(iaas_availability_zones.first['iaas_identifier'])
            browser.click_on 'Save'
          when OpsManagerUiDrivers::VSPHERE_IAAS_TYPE
            browser.click_on 'Assign Availability Zones'
            browser.select(iaas_availability_zones.first['name'])
            browser.click_on 'Save'
        end
      end

      def assign_networks(ops_manager)
        if ops_manager.vcenter
          deployment_network = ops_manager.networks[0]

          infrastructure_network =
            ops_manager.networks[1] ? ops_manager.networks[1] : ops_manager.networks[0]

          assign_networks_vsphere(
            infrastructure_network: infrastructure_network['name'],
            deployment_network:     deployment_network['name'],
          )
        else
          assign_network(deployment_network: ops_manager.networks[0]['name'])
        end
      end

      def customize_resource_config(resource_config)
        browser.click_on 'Resource Config'
        if resource_config
          browser.fill_in('product_resources_form[director][persistent_disk][value]', with: resource_config.persistent_disk)
        end
      end

      def assign_networks_vsphere(infrastructure_network:, deployment_network:)
        browser.click_on 'Assign Networks'

        browser.within browser.find '#director_network_assignments_infrastructure_network' do
          browser.select infrastructure_network
        end

        browser.within browser.find '#director_network_assignments_deployment_network' do
          browser.select deployment_network
        end
        browser.click_on 'Save'
      end

      def assign_network(deployment_network:)
        browser.click_on 'Assign Networks'

        browser.select(deployment_network, from: 'Network')
        browser.click_on 'Save'
      end

      def configure_vm_passwords(use_generated_passwords: true)
        browser.click_on 'VM Passwords'
        if use_generated_passwords
          browser.choose('Generate passwords')
        else
          browser.choose('Use default BOSH password')
        end
        browser.click_on 'Save'
        browser.wait { browser.has_text?('Settings updated') }
      end

      private

      attr_reader :browser, :iaas_configuration


      def availability_zones
        @availability_zones ||= Version15::AvailabilityZones.new(browser: browser)
      end

      def networks
        @networks ||= Version15::Networks.new(browser: browser)
      end
    end
  end
end
