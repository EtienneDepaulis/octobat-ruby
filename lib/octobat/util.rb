module Octobat
  module Util
    def self.expand_nested_objects(h)
      case h
      when Hash
        res = {}
        h.each { |k, v| res[k] = expand_nested_objects(v) unless v.nil? }
        res
      when Array
        if !h.empty? && h.first.is_a?(Hash)
          res = {'' => h.map{|v| expand_nested_objects(v)}}
        else
          res = h
        end
        res
      else
        h
      end
    end

    def self.objects_to_ids(h)
      case h
      when APIResource
        h.id
      when Hash
        res = {}
        h.each { |k, v| res[k] = objects_to_ids(v) unless v.nil? }
        res
      when Array
        h.map { |v| objects_to_ids(v) }
      else
        h
      end
    end

    def self.object_classes
      @object_classes ||= {
        # data structures
        'list' => ListObject,

        # business objects
        'payment_mode' => PaymentMode,
        'payment' => Payment,
        'invoice_numbering_sequence' => InvoiceNumberingSequence,
        'credit_note_numbering_sequence' => CreditNoteNumberingSequence,
        'invoice' => Invoice,
        'item' => Item,
        'customer' => Customer,
        'transaction' => Transaction
      }
    end

    def self.convert_to_octobat_object(resp, api_key)
      case resp
      when Array
        resp.map { |i| convert_to_octobat_object(i, api_key) }
      when Hash
        # Try converting to a known object class.  If none available, fall back to generic OctobatObject
        object_classes.fetch(resp[:object], OctobatObject).construct_from(resp, api_key)
      else
        resp
      end
    end

    def self.file_readable(file)
      # This is nominally equivalent to File.readable?, but that can
      # report incorrect results on some more oddball filesystems
      # (such as AFS)
      begin
        File.open(file) { |f| }
      rescue
        false
      else
        true
      end
    end

    def self.symbolize_names(object)
      case object
      when Hash
        new_hash = {}
        object.each do |key, value|
          key = (key.to_sym rescue key) || key
          new_hash[key] = symbolize_names(value)
        end
        new_hash
      when Array
        object.map { |value| symbolize_names(value) }
      else
        object
      end
    end

    def self.url_encode(key)
      URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def self.flatten_params(params, parent_key=nil)
      result = []
      params.each do |key, value|
        calculated_key = parent_key ? "#{parent_key}[#{url_encode(key)}]" : url_encode(key)
        if value.is_a?(Hash)
          result += flatten_params(value, calculated_key)
        elsif value.is_a?(Array)
          result += flatten_params_array(value, calculated_key)
        else
          result << [calculated_key, value]
        end
      end
      result
    end

    def self.flatten_params_array(value, calculated_key)
      result = []
      value.each do |elem|
        if elem.is_a?(Hash)
          result += flatten_params(elem, calculated_key)
        elsif elem.is_a?(Array)
          result += flatten_params_array(elem, calculated_key)
        else
          result << ["#{calculated_key}[]", elem]
        end
      end
      result
    end

    # The secondary opts argument can either be a string or hash
    # Turn this value into an api_key and a set of headers
    def self.parse_opts(opts)
      case opts
      when NilClass
        return nil, {}
      when String
        return opts, {}
      when Hash
        headers = {}
        if opts[:idempotency_key]
          headers[:idempotency_key] = opts[:idempotency_key]
        end
        if opts[:octobat_account]
          headers[:octobat_account] = opts[:octobat_account]
        end
        return opts[:api_key], headers
      else
        raise TypeError.new("parse_opts expects a string or a hash")
      end
    end
  end
end
