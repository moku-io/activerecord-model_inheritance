require 'active_support'
require 'active_record'
require_relative 'error'
require_relative 'view_definition'

module ActiveRecord
  module ModelInheritance
    class InheritanceError < Error; end

    module Model
      extend ActiveSupport::Concern

      included do
        class_attribute :model_inheritance_base_model
        class_attribute :model_inheritance_inner_model
        class_attribute :model_inheritance_base_name
        class_attribute :model_inheritance_inner_name
        class_attribute :model_inheritance_view_definition
        class_attribute :model_inheritance_attributes_mapping

        self.primary_key = :id
        self.record_timestamps = false
      end

      class_methods do
        def derives_from(base_model,
                         base_reference_name: ModelInheritance.base_reference_name,
                         inner_reference_name: ModelInheritance.inner_reference_name,
                         inherit_enums: ModelInheritance.inherit_enums,
                         inner_base_class: ModelInheritance.inner_base_class,
                         inner_class_name: ModelInheritance.inner_class_name,
                         delegate_missing_to_base: ModelInheritance.delegate_missing_to_base,
                         &block)
          self.model_inheritance_base_name = base_reference_name
          self.model_inheritance_inner_name = inner_reference_name
          self.model_inheritance_base_model = base_model

          base_ref_foreign_key = "#{model_inheritance_base_model.model_name.singular}_id"
          base_ref = proc do
            belongs_to base_reference_name,
                       class_name: "::#{base_model.name}",
                       foreign_key: base_ref_foreign_key
          end

          inner_model = Class.new inner_base_class do
            instance_exec(&block) if block.present?
            instance_exec(&base_ref)
          end
          instance_exec(&block) if block.present?
          instance_exec(&base_ref)

          const_set inner_class_name, inner_model
          belongs_to inner_reference_name, class_name: inner_class_name, foreign_key: :id

          # the secret ingredient
          accepts_nested_attributes_for base_reference_name
          accepts_nested_attributes_for inner_reference_name

          self.model_inheritance_inner_model = inner_model
          self.model_inheritance_view_definition = ViewDefinition.from_model self
          self.model_inheritance_attributes_mapping = model_inheritance_view_definition.attributes_mapping

          # prevents attributes from being touched when updating
          # not strictly necessary, but better safe than sorry
          attr_readonly attribute_names.map(&:to_sym)

          if inherit_enums
            base_model.defined_enums.each do |attribute, enum_values|
              attribute = attribute.to_sym
              enum attribute, enum_values if model_inheritance_attributes_mapping[:base].include? attribute
            end
          end

          delegate_missing_to base_reference_name if delegate_missing_to_base
        end

        def partition_attributes attributes
          inner_attributes = attributes.select { |key| model_inheritance_attributes_mapping[:inner].include? key.to_sym }
          base_attributes = attributes.select { |key| model_inheritance_attributes_mapping[:base].include? key.to_sym }

          [inner_attributes, base_attributes]
        end

        def create(...)
          super.reload
        end

        def create!(...)
          super.reload
        end

        # overriding the following methods to prevent ConnectionAdapter from touching the underlying view

        def _insert_record(...)
          0
        end

        def _update_record(...)
          0
        end

        def _delete_record(...)
          0
        end
      end

      def save(**options, &)
        prepare_save
        super && _model_inheritance_base.save
      end

      def save!(**options, &)
        prepare_save
        super
        _model_inheritance_base.save!
      end

      def destroy
        _model_inheritance_inner.destroy
        super
      end

      def delete
        _model_inheritance_inner.delete
        super
      end

      def _model_inheritance_base
        public_send model_inheritance_base_name
      end

      def _model_inheritance_inner
        public_send model_inheritance_inner_name
      end

    private

      def prepare_save
        inner_attributes, base_attributes = self.class.partition_attributes attributes_for_database

        if new_record?
          unless _model_inheritance_base.present?
            raise InheritanceError, "#{model_inheritance_base_name} must be present"
          end

          # pass updated base attributes to base model
          # this way it gets automatically updated
          base_attributes.compact!
          _model_inheritance_base.assign_attributes base_attributes if base_attributes.present?

          attributes = {
            model_inheritance_base_name                         => _model_inheritance_base,
            "#{model_inheritance_inner_name}_attributes".to_sym => inner_attributes
          }
        else
          inner_attributes[:id] = id
          base_attributes[:id] = _model_inheritance_base.id

          attributes = {
            "#{model_inheritance_base_name}_attributes".to_sym  => base_attributes,
            "#{model_inheritance_inner_name}_attributes".to_sym => inner_attributes
          }
        end

        assign_attributes attributes
      end
    end
  end
end
