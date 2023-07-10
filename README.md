# Model Inheritance

An attempt at real inheritance for ActiveRecord models.

This gem leverages database views (thanks to [Scenic](https://github.com/scenic-views/scenic)) to compose models
from other models, kind of like POROs inheritance [with limitations](#limitations). Views are defined using
[Arel](https://www.rubydoc.info/gems/arel) instead of SQL, which is cleaner and allows for easier integration.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activerecord-model_inheritance', '~> 1.0'
```

And then execute:

```bash
bundle
```

## Usage

First of all, if you want to make intensive use of this gem, being familiar on how [Scenic](https://github.com/scenic-views/scenic)
works is highly recommended.

### Quickstart

Assuming you want a new `DerivedModel` that inherits from a preexisting `BaseModel`, follow these steps:

- Generate the new model and its view definition:
    ```bash
    rails g active_record:model_inheritance:model DerivedModel BaseModel
    ```

- Edit the generated model and definition, if needed

- Generate the SQL definition of the view and the initial migration:
    ```bash
    rails g active_record:model_inheritance:view DerivedModel
    ```

- Edit the generated migration if needed

- Finally, run the migration:
    ```bash
    rails db:migrate
    ```

Keep in mind that you need to generate a new version of the SQL definition whenever your view definition changes,
for example when you want to add some fields to the derived model.
To do so, just run the same generator as again:
```bash
rails g active_record:model_inheritance:view DerivedModel
```
This will take care of everything, including generating the migration to update the view.
It works similarly to Scenic.

### Concepts

A database view is like a _virtual table_ where the schema, as well as the data it contains, are
defined by a plain old SQL query. Of course, since views are just query results disguised as tables, you can't write into them.
So, at the end of the day, all this gem does is enabling write operations to Scenic view backed models.

To achieve something _resembling_ real inheritance between models, the **inner model** is introduced,
which is a third entity between the **base model** (the one you want to inherit from)
and the **derived model** (the new one you're creating).

The **inner model** holds the additional pieces your **derived model** should have.

When you apply changes to a **derived model**, those changes are mapped to **inner** and **base** models.
For example, if the **derived model** has the fields `foo` and `bar`, coming respectively from **inner** and **base** models,
changes to `foo` will be saved to the **inner model**, and changes to `bar` will be saved to the **base model**.
This way, the database view backing the **derived model** is always accessed in read-only mode.

### Configuration

If you're using Rails, the following is the code you would put inside an initializer
to configure this gem as it is configured by default. If you're ok with this defaults, then you don't need to
configure anything.
```ruby
# config/initializers/model_inheritance.rb

ActiveRecord::ModelInheritance.configure do |config|
  ## derived model options
  
  # name of the dynamically generated inner model class
  config.inner_class_name = 'Inner'

  # base class of the dynamically generated inner model
  config.inner_base_class = ApplicationRecord
  
  # name of the belongs_to association from derived model to base model
  config.base_reference_name = :model_inheritance_base

  # name of the belongs_to association from derived model to its own inner model
  config.inner_reference_name = :model_inheritance_inner

  # whether to inherit enums from the base model
  # only enums relevant to inherited fields will be added
  config.inherit_enums = true

  # whether to delegate missing methods from derived model to base model
  config.delegate_missing_to_base = true

  ## paths options

  # these are self explanatory
  config.models_path = Rails.root.join('app/models')
  config.migrations_path = Rails.root.join('db/migrate')

  # where to save generated SQL definitions (Scenic default)
  config.views_path = Rails.root.join('db/views')

  # where to save view definitions
  config.definitions_path = Rails.root.join('db/views/model_inheritance')
end
```
If you're not using Rails, the default configuration stays the same, except:
```ruby
config.inner_base_class = ActiveRecord::Base

config.models_path = Pathname('app/models')
config.migrations_path = Pathname('db/migrate')

config.views_path = Pathname('db/views')
config.definitions_path = Pathname('db/views/model_inheritance')
```

You can pass options to `derives_from` if you want to override the global derived models configuration on a per model basis:
```ruby
class DerivedModel < ApplicationRecord
  include ActiveRecord::ModelInheritance::Model
  
  derives_from BaseModel,
               inner_class_name: 'Inner',
               inner_base_class: ApplicationRecord,
               base_reference_name: :model_inheritance_base,
               inner_reference_name: :model_inheritance_inner,
               inherit_enums: true,
               delegate_missing_to_base: true
end
```

### View definitions
A view definition is responsible of:
- providing a convenient way of defining views using Arel
- keeping a map of which attributes belong respectively to the base and inner model

By default, the derived model will get **all** the fields from base and inner.
If that's not what you want, you can override the default behaviour like in the following example:
```ruby
# db/views/model_inheritance/derived_models.rb

ActiveRecord::ModelInheritance::ViewDefinition.define_derived_view DerivedModel do |inner_table, base_table|
  inner_table
    # all fields from inner
    .project(inner_table[Arel.star])
    # only some fields from base
    .project(
            base_table[:foo],
            base_table[:bar],
            base_table[:baz]
    )
    .join(base_table)
    .on(inner_table[:model_inheritance_base_id].eq base_table[:id])
end
```
Here, Arel is used to describe how you want the base and inner table joined.
The block parameters `inner_table` and `base_table` are both [Arel::SelectTable](https://www.rubydoc.info/gems/arel/Arel/Table)s,
representing the inner model table and base model table respectively.
The code inside the block **must** evaluate to [Arel::SelectManager](https://www.rubydoc.info/gems/arel/Arel/SelectManager).
Note that if you set the option `base_reference_name` to something different to `:model_inheritance_base`, you have to
change the join condition accordingly.

When you run the `active_record:model_inheritance:view` generator, one of the things that's done is converting that Arel::SelectManager
(the default one or your custom provided one) to SQL. In the case of the above example, the generated SQL will look something
like this:
```sql
/* db/views/derived_models_v01.sql */

SELECT "derived_model_inners".*,
       "base_models"."foo",
       "base_models"."bar",
       "base_models"."baz"
FROM "derived_model_inners"
INNER JOIN "base_models"
    ON "derived_model_inners"."model_inheritance_base_id" = "base_models"."id"
```
This is how the database view backing the derived model will be created.

### Sharing code between derived and inner
Sometimes it could be useful to have code replicated in both derived and inner models.
This can be done by passing a block to `derives_from`.
```ruby
class DerivedModel < ApplicationRecord
  include ActiveRecord::ModelInheritance::Model

  derives_from BaseModel do
    def foo
      # ...
    end
  end
end
```
In the above example, `foo` you will be declared in both derived and inner models.

### Accessing the inner model
If for some reason you want to directly access the inner model, you can:
```ruby
DerivedModel::Inner   # the inner model class

DerivedModel::Foo     # in case you've set inner_class_name to 'Foo'

DerivedModel.first._model_inheritance_inner   # instance of the inner model
```

### A few words on multiple inheritance
This gem doesn't strictly prohibit multiple inheritance, and in _in theory_ it should be possible to implement.
Currently there are no plans on this, but if you find a clean solution you can share your work with us! (see [Contributing](#contributing))

## Limitations
- A derived model is not a subclass of its base model
- Query methods called on base models will return only base models
- Query methods called on derived models will return only derived models

## Future developments
- Improved and more comprehensive documentation
- Some ways around current limitations
- Testing with a dummy Rails application

## Version numbers

Model Inheritance loosely follows [Semantic Versioning](https://semver.org/), with a hard guarantee that breaking changes to the public API will always coincide with an increase to the `MAJOR` number.

Version numbers are in three parts: `MAJOR.MINOR.PATCH`.

- Breaking changes to the public API increment the `MAJOR`. There may also be changes that would otherwise increase the `MINOR` or the `PATCH`.
- Additions, deprecations, and "big" non breaking changes to the public API increment the `MINOR`. There may also be changes that would otherwise increase the `PATCH`.
- Bug fixes and "small" non breaking changes to the public API increment the `PATCH`.

Notice that any feature deprecated by a minor release can be expected to be removed by the next major release.

## Changelog

Full list of changes in [CHANGELOG.md](CHANGELOG.md)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/moku-io/activerecord-model_inheritance.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
