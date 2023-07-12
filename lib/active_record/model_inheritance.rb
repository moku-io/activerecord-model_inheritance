require 'active_record'
require 'active_support'
require 'scenic'
require_relative 'model_inheritance/version'

module ActiveRecord
  module ModelInheritance
    include ActiveSupport::Configurable

    config.define_singleton_method :define_lazy_property do |key, &block|
      self[key] = nil

      define_singleton_method key do
        self[key] || (self[key] = block.call)
      end
    end

    config.define_singleton_method :define_lazy_path do |name, *dirs|
      define_lazy_property name do
        if defined?(Rails.root) && Rails.root
          Rails.root.join(*dirs)
        else
          Pathname(dirs.join '/')
        end
      end

      define_singleton_method "#{name}=".to_sym do |path|
        self[name] = Pathname(path)
      end
    end

    config.base_reference_name = :model_inheritance_base
    config.inner_reference_name = :model_inheritance_inner
    config.inner_class_name = 'Inner'
    config.inherit_enums = true
    config.delegate_missing_to_base = true

    config.define_lazy_path :views_path, 'db', 'views'
    config.define_lazy_path :models_path, 'app', 'models'
    config.define_lazy_path :migrations_path, 'db', 'migrate'
    config.define_lazy_path :definitions_path, 'db', 'views', 'model_inheritance'

    config.define_lazy_property :inner_base_class do
      if defined? ApplicationRecord
        ApplicationRecord
      else
        ActiveRecord::Base
      end
    end

    singleton_class.delegate(*config.keys, to: :config)
  end
end

require_relative 'model_inheritance/error'
require_relative 'model_inheritance/model'
require_relative 'model_inheritance/view_definition'
