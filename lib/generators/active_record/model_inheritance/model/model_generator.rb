require 'rails/generators'
require 'active_record/model_inheritance'

module ActiveRecord
  module ModelInheritance
    module Generators
      class ModelGenerator < Rails::Generators::NamedBase
        source_root File.expand_path('templates', __dir__)

        desc 'Create derived model and definition files'

        argument :derives_from, type: :string, optional: false

        class_option :only_definition,
                     type: :boolean,
                     required: false,
                     default: false,
                     desc: 'Whether or not to generate only the definition file'

        def generate_model
          return if skip_generate_model?

          if rails_application?
            invoke 'model',
                   [file_path.singularize],
                   options.merge(
                     fixture_replacement: false,
                     migration: false
                   )
          else
            template 'model.erb', ModelInheritance.models_path.join("#{file_path.singularize}.rb")
          end
        end

        def inject_configuration_to_model
          return if skip_generate_model?

          inject_into_class ModelInheritance.models_path.join("#{file_path.singularize}.rb"), class_name do
            evaluate_template 'model_config.erb'
          end
        end

        def create_definition_file
          template 'definition.erb', ModelInheritance.definitions_path.join("#{table_name}.rb")
        end

        no_tasks do
          def evaluate_template source
            source = File.expand_path find_in_source_paths(source.to_s)

            erb = ERB.new(
              File.read(source),
              trim_mode: '-',
              eoutvar: '@output_buffer'
            )

            erb.result binding
          end

          def rails_application?
            defined?(Rails.application) && Rails.application.present?
          end

          def skip_generate_model?
            options[:only_definition]
          end

          def formatted_base_name
            "::#{derives_from.camelize}"
          end
        end
      end
    end
  end
end
