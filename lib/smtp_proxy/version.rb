module SMTPProxy
  module Version
    extend self

    MAJOR = 1
    MINOR = 0
    PATCH = 0
  end

  VERSION_ARRAY = [ Version::MAJOR, Version::MINOR, Version::PATCH ]
  VERSION_STRING = VERSION_ARRAY.join('.')
  VERSION = VERSION_STRING
end