require "java"

# this is mainly for usage with JrJackson json parsing in :raw mode which genenerates
# Java::JavaUtil::ArrayList and Java::JavaUtil::LinkedHashMap native objects for speed.
# these object already quacks like their Ruby equivalents Array and Hash but they will
# not test for is_a?(Array) or is_a?(Hash) and we do not want to include tests for
# both classes everywhere. see LogStash::JSon.

class Array
  # enable class equivalence between Array and ArrayList
  # so that ArrayList will work with case o when Array ...
  def self.===(other)
    return true if other.is_a?(Java::JavaUtil::Collection)
    super
  end
end

class Hash
  # enable class equivalence between Hash and LinkedHashMap
  # so that LinkedHashMap will work with case o when Hash ...
  def self.===(other)
    return true if other.is_a?(Java::JavaUtil::Map)
    super
  end
end


# this is a temporary fix to solve a bug in JRuby where classes implementing the Map interface, like LinkedHashMap
# have a bug in the has_key? method that is implemented in the Enumerable module that is somehow mixed in the Map interface.
# this bug makes has_key? (and all its aliases) return false for a key that has a nil value.
# Only LinkedHashMap is patched here because patching the Map interface is not working.
# TODO find proper fix, and submit upstream
# releavant JRuby files:
# https://github.com/jruby/jruby/blob/master/core/src/main/ruby/jruby/java/java_ext/java.util.rb
# https://github.com/jruby/jruby/blob/master/core/src/main/java/org/jruby/java/proxies/MapJavaProxy.java
class Java::JavaUtil::LinkedHashMap
  def has_key?(key)
    self.containsKey(key)
  end
  alias_method :include?, :has_key?
  alias_method :member?, :has_key?
  alias_method :key?, :has_key?
end

module java::util::Map
  # have Map objects like LinkedHashMap objects report is_a?(Array) == true
  def is_a?(clazz)
    return true if clazz == Hash
    super
  end
end

module java::util::Collection
  # have Collections objects like ArrayList report is_a?(Array) == true
  def is_a?(clazz)
    return true if clazz == Array
    super
  end

  # support the Ruby Array delete method on a Java Collection
  def delete(o)
    self.removeAll([o]) ? o : block_given? ? yield : nil
  end

  # support the Ruby intersection method on Java Collection
  def &(other)
    # transform self into a LinkedHashSet to remove duplicates and preserve order as defined by the Ruby Array intersection contract
    duped = Java::JavaUtil::LinkedHashSet.new(self)
    duped.retainAll(other)
    duped
  end

  # support the Ruby union method on Java Collection
  def |(other)
    # transform self into a LinkedHashSet to remove duplicates and preserve order as defined by the Ruby Array union contract
    duped = Java::JavaUtil::LinkedHashSet.new(self)
    duped.addAll(other)
    duped
  end
end