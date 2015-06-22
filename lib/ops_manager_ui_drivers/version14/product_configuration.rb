module OpsManagerUiDrivers
  module Version14
    class ProductConfiguration
      attr_reader :product_name

      def initialize(browser:, product_name:)
        @browser = browser
        @product_name = product_name
      end

      def upload_stemcell(stemcell_file_path)
        visit_product_page
        browser.click_on "show-#{product_name}-stemcell-assignment-action"
        browser.attach_file('product_stemcell[file]', stemcell_file_path, {visible: false})
        browser.wait {
          browser.has_text?("Stemcell '#{File.basename(stemcell_file_path)}' has been uploaded successfully.")
        }
      end

      def product_form(form_name)
        Version14::ProductForm.new(browser: browser, product_name: product_name, form_name: form_name)
      end

      def set_resource_size_value(job_resource_name, resource_name, value)
	resource_config_form = product_form("#{product_name}-resource-sizes")
	resource_config_form.open_form
	product_form('product_resources_form').nested_property(job_resource_nam, "#{resource_name}][value").set(value)
	resource_config_form.save_form
      end

      private

      attr_reader :browser, :product_name

      def visit_product_page
        browser.visit '/'
        browser.click_on "show-#{product_name}-configure-action"
      end
    end
  end
end
