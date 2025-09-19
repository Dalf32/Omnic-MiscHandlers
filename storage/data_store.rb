# DataStore
#
# AUTHOR::  Kyle Mullins

require_relative '../util/hash_util'

class DataStore
  include HashUtil

  protected

  def retrieve_object(redis, object_key, object_class)
    obj_json = redis.get(object_key)
    return nil if obj_json.nil?

    from_json(object_class, obj_json)
  end

  def save_object(redis, object_key, object_data)
    redis.set(object_key, to_json(object_data))
  end

  def retrieve_from_hash(redis, hash_key, object_key, object_class)
    obj_json = redis.hget(hash_key, object_key)
    return nil if obj_json.nil?

    from_json(object_class, obj_json)
  end

  def save_to_hash(redis, hash_key, object_key, object_data)
    redis.hset(hash_key, object_key, to_json(object_data))
  end

  def retrieve_multiple(redis, object_class, object_keys)
    redis.mget(object_keys).map do |obj_json|
      next if obj_json.nil?

      from_json(object_class, obj_json)
    end
  end

  def save_multiple(redis, objects_hash)
    redis.mset(*objects_hash.to_a.map { |key, obj| [key, to_json(obj)] }.flatten)
  end

  def from_json(object_class, obj_json)
    object_class.from_hash(symbolize_keys(JSON.parse(obj_json)))
  end

  def to_json(obj_data)
    JSON.generate(obj_data.to_hash)
  end
end
