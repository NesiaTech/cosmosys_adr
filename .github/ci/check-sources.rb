# frozen_string_literal: true

# Checks that need neither Redmine nor a database, run with the Ruby of the
# deployment's Redmine image: every Ruby file compiles without warnings, and
# every locale defines exactly the keys of the English one.
#
#   ruby .github/ci/check-sources.rb PLUGIN_DIR

require 'open3'
require 'yaml'

root = ARGV.fetch(0)
failures = []

Dir.glob('**/*.rb', base: root).sort.each do |path|
  output, status = Open3.capture2e('ruby', '-wc', File.join(root, path))
  failures << "#{path}: #{output.strip}" unless status.success? && output.strip == 'Syntax OK'
end

def locale_keys(tree, prefix = nil)
  tree.flat_map do |key, value|
    name = [prefix, key].compact.join('.')
    value.is_a?(Hash) ? locale_keys(value, name) : [name]
  end
end

locales = Dir.glob('config/locales/*.yml', base: root).sort.to_h do |path|
  locale = File.basename(path, '.yml')
  [path, locale_keys(YAML.load_file(File.join(root, path)).fetch(locale))]
end
english = locales.fetch('config/locales/en.yml')
locales.each do |path, keys|
  (english - keys).each { |key| failures << "#{path} lacks #{key}" }
  (keys - english).each { |key| failures << "#{path} has #{key}, which config/locales/en.yml lacks" }
end

puts "#{Dir.glob('**/*.rb', base: root).size} Ruby files and #{locales.size} locales checked"
abort(failures.join("\n")) unless failures.empty?
