class Appsignal::Event::MopedEvent < Appsignal::Event
  def initialize(name, start, ending, transaction_id, payload)
    super(name, start, ending, transaction_id, transform_payload(payload))
  end

  def transform_payload(payload)
    if payload[:ops] && payload[:ops].length > 0
      transformed_ops = [].tap do |arr|
        payload[:ops].each do |op|
          arr << payload_from_op(op.dup)
        end
      end
      payload[:ops] = transformed_ops
    end
    payload
  end

  def payload_from_op(payload)
    case payload.class.to_s
    when 'Moped::Protocol::Command'
      {
        :type     => 'Command',
        :database => payload.full_collection_name,
        :selector => sanitize(payload.selector)
      }
    when 'Moped::Protocol::Query'
      {
        :type     => 'Query',
        :database => payload.full_collection_name,
        :selector => sanitize(payload.selector),
        :flags    => payload.flags,
        :limit    => payload.limit,
        :skip     => payload.skip,
        :fields   => payload.fields
      }
    when 'Moped::Protocol::Delete'
      {
        :type     => 'Delete',
        :database => payload.full_collection_name,
        :selector => sanitize(payload.selector),
        :flags    => payload.flags,
      }
    when 'Moped::Protocol::Insert'
      {
        :type       => 'Insert',
        :database   => payload.full_collection_name,
        :documents  => sanitize(payload.documents),
        :flags      => payload.flags,
      }
    when 'Moped::Protocol::Update'
      {
        :type     => 'Update',
        :database => payload.full_collection_name,
        :selector => sanitize(payload.selector),
        :update   => sanitize(payload.update),
        :flags    => payload.flags,
      }
    else
      {
        :type     => payload.class.to_s.gsub('Moped::Protocol::', ''),
        :database => payload.full_collection_name
      }
    end
  end

  def sanitize(params)
    if params.is_a?(Hash)
      {}.tap do |hsh|
        params.each do |key, val|
          hsh[key] = sanitize(val)
        end
      end
    elsif params.is_a?(Array)
      if params.first.is_a?(String)
        ['?']
      else
        params.map do |item|
          sanitize(item)
        end
      end
    else
      '?'
    end
  end
end
