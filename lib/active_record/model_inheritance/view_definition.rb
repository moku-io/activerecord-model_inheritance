require 'arel'
require_relative 'error'

module ActiveRecord
  module ModelInheritance
    class DefinitionError < Error; end

    class ViewDefinition
      attr_reader :definition
      attr_reader :model_class

      def initialize model_class, definition
        @model_class = model_class
        @definition = definition
      end

      def to_sql
        @definition.to_sql
      end

      def attributes_mapping
        definition
          .projections
          .each_with_object({base: [], inner: []}) do |projection, attributes_mapping|
            if projection.is_a? Arel::Nodes::As
              relation = projection.left.relation
              name = projection.right
            else
              relation = projection.relation
              name = projection.name
            end

            case relation
            when model_class.model_inheritance_inner_model.arel_table
              relation_type = :inner
              relation_model = model_class.model_inheritance_inner_model
            when model_class.model_inheritance_base_model.arel_table
              relation_type = :base
              relation_model = model_class.model_inheritance_base_model
            else
              raise DefinitionError, "Invalid \"#{relation}\" relation"
            end

            attributes = if name == Arel.star
                           relation_model.attribute_names.map(&:to_sym)
                         else
                           [name.to_sym]
                         end

            attributes_mapping[relation_type] += attributes
          end
      end

      def self.from_model model_class
        unless model_class.include? Model
          raise ArgumentError, "#{model_class.name} doesn't include ActiveRecord::ModelInheritance::Model"
        end

        ViewDefinition.from_name model_class.model_name.plural
      end

      def self.from_name name
        definition_filename = Pathname(ModelInheritance.config.definitions_path).join "#{name}.rb"
        raise ArgumentError, "Definition for \"#{name}\" doesn't exist" unless definition_filename.file?

        eval File.read definition_filename
      end

      def self.define_derived_view model_class, &block
        inner_model = model_class.model_inheritance_inner_model
        base_model = model_class.model_inheritance_base_model

        inner_table = inner_model.arel_table
        base_table = base_model.arel_table

        definition = if block_given?
                       block.call(inner_table, base_table).tap do |d|
                         unless d.is_a? Arel::SelectManager
                           raise DefinitionError, 'Defined view must evaluate to Arel::SelectManager'
                         end
                       end
                     else
                       selected_base_columns = if inner_model.primary_key == base_model.primary_key
                                                 # this is a common naming conflict problem
                                                 # makes sense to try and solve automatically

                                                 # just delete the base primary key from columns that will be selected
                                                 base_model
                                                   .column_names
                                                   .dup
                                                   .delete_if { |column_name| column_name == base_model.primary_key }
                                               else
                                                 base_model.column_names
                                               end.map { |column_name| base_table[column_name.to_sym] }

                       base_reference = model_class
                                          .reflect_on_association(model_class.model_inheritance_base_name)
                                          .foreign_key
                                          .to_sym

                       inner_table
                         .project(inner_table[Arel.star])
                         .project(*selected_base_columns)
                         .join(base_table)
                         .on(inner_table[base_reference].eq base_table[base_model.primary_key])
                     end

        ViewDefinition.new model_class, definition
      end
    end
  end
end
