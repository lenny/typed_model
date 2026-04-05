# TypedModel

A lightweight attribute declaration, validation, and type-coercion framework for Ruby. Include `TypedModel::ModelBase` in a class to get:

- **`attribute`** declarations with type and validation options
- **`initialize(values)`** — construct from a hash
- **`attributes=`** — bulk-assign from a hash
- **`valid?`** / **`errors`** — run validations and inspect failures
- **`to_data`** — serialize to a plain hash

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'typed_model'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install typed_model

## Built-in Types

`:string`, `:integer`, `:boolean`, `:timestamp`, `:map`, `:seq`

## Basic Example

```ruby
class Employee
  include TypedModel::ModelBase

  attribute :name
  attribute :a_boolean, type: :boolean
  attribute :an_integer, type: :integer
  attribute :a_timestamp, type: :timestamp
  attribute :widget1, type: :map
  attribute :address, type: Address
  attribute :addresses, seq_of: Address
  attribute :colors, type: :seq
end
```

## Sequences

```ruby
# non-empty/nil sequence
attribute :a_seq, type: :seq, validations: [:required]

# typed sequence of strings
attribute :a_seq, seq_of: :string

# sequence of Address models
attribute :a_seq, seq_of: Address

# sequence of [string, integer] pairs
attribute :a_seq, seq_of: [:string, :integer]

# sequence with nested type and validations
attribute :a_seq, seq_of: { type: Address, validations: [:some_validation] }
```

## Maps

```ruby
# string -> integer
attribute :a_map, map_of: [:string, :integer]

# required map
attribute :a_map, type: :map, validations: [:required]

# map of maps
attribute :map_of_maps, map_of: [:string, [:string, :integer]]
```

## Validations

Primitive types (`:string`, `:integer`, `:timestamp`, `:boolean`, etc.) are automatically validated. Supply built-in or custom validators via the `validations:` option on `attribute`:

```ruby
attribute :name, type: :string, validations: [:required]
attribute :email, type: :string, validations: [:not_blank]
attribute :started_at, type: :timestamp, validations: [:required]
```

### Built-in Validators

| Keyword       | Fails when                                      | Error key  |
| ------------- | ----------------------------------------------- | ---------- |
| `:required`   | value is `nil` or empty                         | `:required` |
| `:not_blank`  | value has no non-whitespace characters           | `:required` |
| `:not_nil`    | value is `nil` (empty is OK)                    | `:required_not_nil` |
| `:timestamp`  | value cannot be parsed as a `Time`              | `:invalid`  |
| `:integer`    | value cannot be coerced to `Integer`            | `:invalid`  |
| `:string`     | value cannot be coerced to `String`             | `:invalid`  |

### Custom Validations

Via `:keyword` — define an `assert_<name>` method:

```ruby
class Employee
  include TypedModel::ModelBase

  attribute :name, validations: [:required, :my_validation]

  def assert_my_validation(attr)
    add_error(attr, 'some error')
  end
end
```

Via `Validator` instance:

```ruby
validator = TypedModel::Validator.new(:foo) do
  ['some error']
end

class Employee
  include TypedModel::ModelBase

  attribute :name, validations: [validator]
end
```

### Before-Validation Callbacks

Register methods that run before the main `validate` pass. Callbacks are inherited and run in ancestor order (parent -> child):

```ruby
class Employee
  include TypedModel::ModelBase

  before_validation :normalize_name

  attribute :name, type: :string

  def normalize_name
    self.name = name&.strip
    add_error(:name, :required) if name.to_s.empty?
  end
end
```

## Validating Payloads and Reporting Errors

Data models are commonly used to validate API request and response payloads. The standard pattern is:

1. Instantiate the model from the payload hash
2. Call `valid?` — returns `true`/`false` and populates `errors`
3. If invalid, report the problems using `errors.inspect`

### The `errors` Object

`errors` is an instance of `TypedModel::Errors` — a hash of attribute names to arrays of error symbols/messages:

```ruby
model.errors[:name]              # => [:required]
model.errors['address/street']   # => [:required]  (nested path)
model.errors['addresses/1/type'] # => [:required]  (array index in path)
model.errors.empty?              # => true/false
```

Iterate all errors:

```ruby
model.each_error { |key, msg| puts "#{key}: #{msg}" }
```

### Validating Inbound Requests

Validate input before processing. Return or raise with `errors.inspect` to convey what's wrong:

```ruby
def process_request(params)
  request = MyRequest.new(params)
  raise "Invalid request: #{request.errors.inspect}" unless request.valid?

  handle(request)
end
```

In a Rails controller, render the errors directly as JSON:

```ruby
def create
  response = MyResponse.new(response_params)

  unless response.valid?
    render json: response.errors.to_h, status: :bad_request
    return
  end

  process(response)
  render json: response, status: :created
end
```

### Validating Outbound Responses

Validate data received from external APIs to catch unexpected payloads early:

```ruby
def build_response(klass, data)
  response = klass.new(data)

  unless response.valid?
    raise InvalidResponse, "Invalid #{klass}: #{response.errors.inspect}"
  end

  response
end
```

Avoid logging raw payload data — it may contain sensitive information. When logging `errors.inspect`, ensure your error messages do not embed raw field values or other sensitive data, and prefer structured or otherwise sanitized error formats where possible.

### Soft vs Hard Failure

Choose the error-handling strategy that fits the context:

```ruby
# Soft — log and return a fallback (caller can continue)
unless request.valid?
  logger.info("Invalid request: #{request.errors.inspect}")
  return empty_response(errors: request.errors, invalid_request: true)
end

# Hard — raise so the caller knows something is fundamentally wrong
unless request.valid?
  raise "Invalid request: #{request.errors.inspect}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lenny/typed_model.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
