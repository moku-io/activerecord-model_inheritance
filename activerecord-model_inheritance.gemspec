require_relative 'lib/active_record/model_inheritance/version'

Gem::Specification.new do |spec|
  spec.name = 'activerecord-model_inheritance'
  spec.version = ActiveRecord::ModelInheritance::VERSION
  spec.authors = ['Moku S.r.l.', 'Marco Volpato']
  spec.email = ['info@moku.io']
  spec.license = 'MIT'

  spec.summary = 'An attempt at real inheritance for ActiveRecord models.'
  spec.description = 'An attempt at real inheritance for ActiveRecord models.'
  spec.homepage = 'https://github.com/moku-io/activerecord-model_inheritance'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/moku-io/activerecord-model_inheritance'
  spec.metadata['changelog_uri'] = 'https://github.com/moku-io/activerecord-model_inheritance/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir __dir__ do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '~> 7.0.0'
  spec.add_dependency 'activesupport', '~> 7.0.0'
  spec.add_dependency 'railties', '~> 7.0.0'
  spec.add_dependency 'scenic', '~> 1.7.0'
end
