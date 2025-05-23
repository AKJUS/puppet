# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))

require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

require 'puppet_x/opensearch/deep_implode'
require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'
require 'puppet_x/opensearch/opensearch_rest_resource'

Puppet::Type.newtype(:opensearch_index_template) do
  extend OpensearchRESTResource

  desc 'Manages Opensearch index templates.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Template name.'
  end

  newproperty(:content) do
    desc 'Structured content of template.'

    validate do |value|
      raise Puppet::Error, 'hash expected' unless value.is_a? Hash
    end

    def insync?(value)
      Puppet_X::Opensearch.deep_implode(value) == \
        Puppet_X::Opensearch.deep_implode(should)
    end

    munge do |value|
      # The Opensearch API will return default empty values for composed_of
      # if it isn't defined in the user index template, so we need to set
      # defaults here to keep the `in` and `should` states consistent if the
      # user hasn't provided any.
      #
      # The value is first stringified, then integers are parse out as
      # necessary, since the Opensearch API enforces some fields to be
      # integers.
      #
      # We also need to fully qualify index settings, since users
      # can define those with the index json key absent, but the API
      # always fully qualifies them.
      { 'composed_of' => [] }.merge(
        Puppet_X::Opensearch.deep_to_i(
          Puppet_X::Opensearch.deep_to_s(
            value.tap do |val|
              if val.key?('template') && val['template'].key?('settings')
                val['template']['settings']['index'] = {} unless val['template']['settings'].key? 'index'
                (val['template']['settings'].keys - ['index']).each do |setting|
                  new_key = if setting.start_with? 'index.'
                              setting[6..-1]
                            else
                              setting
                            end
                  val['template']['settings']['index'][new_key] = \
                    val['template']['settings'].delete setting
                end
              end
            end
          )
        )
      )
    end
  end

  newparam(:source) do
    desc 'Puppet source to file containing template contents.'

    validate do |value|
      raise Puppet::Error, 'string expected' unless value.is_a? String
    end
  end

  # rubocop:disable Style/SignalException
  validate do
    # Ensure that at least one source of template content has been provided
    if self[:ensure] == :present
      fail Puppet::ParseError, '"content" or "source" required' \
        if self[:content].nil? && self[:source].nil?

      if !self[:content].nil? && !self[:source].nil?
        fail(
          Puppet::ParseError,
          "'content' and 'source' cannot be simultaneously defined"
        )
      end
    end

    # If a source was passed, retrieve the source content from Puppet's
    # FileServing indirection and set the content property
    unless self[:source].nil?
      fail(format('Could not retrieve source %s', self[:source])) unless Puppet::FileServing::Metadata.indirection.find(self[:source])

      tmp = if !catalog.nil? \
                && catalog.respond_to?(:environment_instance)
              Puppet::FileServing::Content.indirection.find(
                self[:source],
                environment: catalog.environment_instance
              )
            else
              Puppet::FileServing::Content.indirection.find(self[:source])
            end

      fail(format('Could not find any content at %s', self[:source])) unless tmp

      self[:content] = if Puppet::Util::Package.versioncmp(Puppet.version, '8.0.0').negative?
                   PSON.load(tmp.content)
                 else
                   JSON.parse(tmp.content)
                 end
    end
  end
  # rubocop:enable Style/SignalException
end
