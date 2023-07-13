require 'active_support'
require_relative 'error'
require_relative 'model'

module ActiveRecord
  module ModelInheritance
    module Base
      extend ActiveSupport::Concern

      included do
        class_attribute :model_inheritance_derived_models, default: []
      end

      class_methods do
        def base_of *derived_models, name: nil
          if derived_models.length > 1
            raise ArgumentError, 'Name cannot be specified if declaring many derived models' if name.present?

            derived_models.each do |derived_model|
              define_derived_model_helpers derived_model
            end
          else
            derived_models.first.tap do |derived_model|
              define_derived_model_helpers derived_model, name
            end
          end
        end

      private

        def define_derived_model_helpers derived_model, name=nil
          if model_inheritance_derived_models.include? derived_model
            raise ArgumentError, "#{derived_model.name} already declared as derived model for #{self.name}"
          end

          raise ArgumentError, "#{derived_model} is not a derived model" unless derived_model.include? Model

          unless derived_model.model_inheritance_base_model == self
            raise ArgumentError, "#{self.name} is not a base model of #{derived_model.name}"
          end

          if name.present?
            name.to_s.downcase
          else
            derived_model.model_name.singular
          end.tap do |derived_name|
            has_one derived_name.to_sym, class_name: "::#{derived_model.name}"

            define_method :"#{derived_name}!" do
              public_send(derived_name) || begin
                                             raise Error,
                                                   "Derived model of type #{derived_model.name} not found for #{self}"
                                           end
            end

            define_method :"#{derived_name}?" do
              public_send(derived_name).present?
            end

            scope derived_name.pluralize.to_sym,
                  lambda {
                    derived_model.where(derived_model.model_inheritance_base_name => self)
                  }
          end

          model_inheritance_derived_models << derived_model
        end
      end
    end
  end
end
