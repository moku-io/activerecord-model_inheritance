require 'rails/generators'
require 'rails/generators/active_record'
require 'active_record/model_inheritance'
require 'active_record/model_inheritance/view_definition'

module ActiveRecord
  module ModelInheritance
    module Generators
      class ViewGenerator < Rails::Generators::NamedBase
        include Rails::Generators::Migration

        desc 'Generate SQL view definition and create initial/update migration'

        source_root File.expand_path('templates', __dir__)

        class_option :skip_migration,
                     type: :boolean,
                     required: false,
                     default: false,
                     desc: 'Whether or not to generate a migration file'

        def create_view_file
          create_file ModelInheritance
                        .views_path
                        .join("#{table_name}_v#{formatted_next_version}.sql"),
                      view_definition.to_sql
        end

        def create_migration_file
          return if skip_generate_migration?

          if creating?
            migration_template(
              'create_migration.erb',
              ModelInheritance.migrations_path.join("create_#{table_name}.rb")
            )
          else
            migration_template(
              'update_migration.erb',
              ModelInheritance.migrations_path.join("update_#{table_name}_to_version_#{formatted_next_version}.rb")
            )
          end
        end

        def self.next_migration_number dir
          ::ActiveRecord::Generators::Base.next_migration_number dir
        end

        no_tasks do
          def current_version
            @current_version ||= ModelInheritance
                                   .views_path
                                   .glob("#{table_name}_v*.sql")
                                   .last
                                   .then { |last_version_file| last_version_file&.basename&.to_s }
                                   .then do |last_version_name|
                                     version_regex
                                       .match(last_version_name)
                                       .try(:[], :version)
                                       .to_i
                                   end
          end

          def next_version
            @next_version ||= current_version.next
          end

          def formatted_next_version
            next_version
              .to_s
              .rjust(2, '0')
          end

          def creating?
            current_version.zero?
          end

          def skip_generate_migration?
            options[:skip_migration]
          end

          def version_regex
            %r{\A#{table_name}_v(?<version>\d+)\.sql\z}
          end

          def formatted_class_name
            class_name.tr('.:', '').pluralize
          end

          def migration_class_name
            if creating?
              "Create#{formatted_class_name}"
            else
              "Update#{formatted_class_name}ToVersion#{next_version}"
            end
          end

          def activerecord_migration_class
            "ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]"
          end

          def formatted_inner_table_name
            ":#{view_definition.model_class.model_inheritance_inner_model.table_name}"
          end

          def formatted_base_name
            ":#{view_definition.model_class.model_inheritance_base_model.model_name.singular}"
          end

          def formatted_table_name
            ":#{table_name}"
          end

          def view_definition
            @view_definition ||= ViewDefinition.from_name table_name
          end
        end
      end
    end
  end
end
