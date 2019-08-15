local Result, Option, Ok, Err

expect_class = (value, expected)->
	assert value.__class == expected,
		"expected type #{expected.__name}<#{expected}>, got " ..
		"#{value.__class.__name}<#{value.__class}>"

class Result
	Ok: 0
	Err: 1

	new: (variant, content)=>
		@variant = variant
		@content = content

	is_ok: => @variant == Ok
	is_err: => @variant == Err

	--- Unwrap a result, returning the content or otherwise erroring
	expect: (error_value)=>
		@content if @is_ok! else error "#{error_value}: #{@content}"

	--- Raise error if is_err!, otherwise return content
	unwrap: =>
		@content if @is_ok! else error content

	--- Raises error if is_ok!, otherwise returns error value
	unwrap_err: =>
		@content if @is_err! else error content

	--- Returns content if is_ok!, otherwise `fallback`
	-- @param fallback
	unwrap_or: (fallback)=>
		@content if @is_ok! else fallback

	--- Returns content if is_ok!, otherwise the called output of `fallback_fn`
	-- @tparam fallback_fn
	unwrap_or_else: (fallback_fn)=>
		@content if @is_ok! else fallback_fn!

	ok: => Option(@content) if @is_ok! else Option!
	err: => Option(@content) if @is_err! else Option!

	--- Map Result<T, E> to Result<U, E> - Error can be kept if is_err!
	-- @tparam function fn Function to use for mapping content
	map: (fn)=>
		Ok fn @content if @is_ok else self

	--- Map Result<T, E> to Result<T, F> - Content can be kept if is_ok!
	-- @tparam function fn Function to use for mapping error
	map_err: (fn)=>
		if @is_err
			return Err fn @content
		self

	--- Return `right` if the variant is `Ok`, otherwise return self's `Err`
	-- @param right
	and_also: (right)=>
		self if @is_error! else right

	--- Return evaluated output of `right_fn` if the variant is `Ok`, otherwise
	-- return self's `Err`
	-- @tparam function right_fn
	and_then: (right_fn)=>
		self if @is_error! else right_fn @content

	--- Return `right` if the variant is `Err`, otherwise return self's `Ok`
	-- @param right
	or_other: (right)=>
		self if @is_ok! else right

	--- Return evaluated output of  `right_fn` if the variant is `Err`,
	-- otherwise return self's `Ok`
	-- @tparam function right_fn
	or_else: (right_fn)=>
		self if @is_ok! else right_fn @content

	--- Transpose a Result of an Option into an Option of a Result
	transpose: =>
		expect_class @content, Result
		if @content\is_some!
			return @variant @content.data -- Some
		Option! -- None

import Ok, Err from Result

result_variant_mt = {
	__call: (...)=> Result self, ...
}

debug.setmetatable Ok, result_variant_mt
debug.setmetatable Err, result_variant_mt

class Option
	new: (some=nil)=>
		if some
			@data = some

	is_some: => @data != nil
	is_none: => @data == nil

	--- Transform an Option<Option<T>> into an Option<T>
	flatten: =>
		expect_class @data, Option
		Option @data\expect!

	--- Unwrap an option, returning the content or otherwise erroring
	-- @param error_value Value raised if variant is None
	expect: (error_value)=>
		@data if @is_some! else Err(error_value)\unwrap!

	--- Moves a value `v` out of `Option<T>` if it is a `Some(v)` variant
	unwrap: =>
		@expect "called Option.unwrap() on a None variant"

	--- Return the contained value if is_some! or a fallback value
	-- @param fallback
	unwrap_or: (fallback)=>
		@data if @is_some! else fallback

	--- Return the contained value if is_some!, otherwise the called output of
	-- `fallback_fn`
	-- @tparam function fallback_fn
	unwrap_or_else: (fallback_fn)=>
		@data if @is_some! else fallback_fn!

	--- Applies a function to the contained value
	-- @tparam function fn Function to use for mapping content
	map: (fn)=>
		Option fn @data if @is_some! else self

	--- Applies a function to the contained value, or returns a fallback
	-- @param fallback
	-- @tparam function fn Function to use for mapping content
	map_or: (fallback, fn)=>
		Option fn @data if @is_some! else fallback

	--- Applies a function to the contained value, or calls fallback function
	-- @tparam function fallback_fn
	-- @tparam function fn Function to use for mapping content
	map_or_else: (fallback_fn, fn)=>
		Option fn @data if @is_some! else fallback_fn!

	--- Transform an `Option<T>` into a `Result<T, E>`, mapping `Some(v)` to
	-- `Ok(v)` and `None` to `Err(error_value)`
	-- @param error_value
	ok_or: (error_value)=>
		if @is_some!
			Ok @data
		else -- None
			Err error_value

	--- Transform an `Option<T>` into a `Result<T, E>`, mapping `Some(v)` to
	-- `Ok(v)` and `None` to `Err(error_fn!)`
	-- @tparam function error_fn
	ok_or_else: (error_fn)=>
		if @is_some!
			Ok @data
		else -- None
			Err error_fn!

	--- Return `None` if already `None`, otherwise call `predicate` function
	-- and returns `Some(v)` if the predicate function returns true, otherwise
	-- None if `predicate` returns false
	-- @tparam function predicate
	filter: (predicate)=>
		if @is_some! and predicate @data
			return @data
		Option!

	--- Return `right` if the variant is `Some`
	-- @param right
	and_also: (right)=>
		self if @is_none! else right

	--- Return evaluated output of `right_fn` if the variant is `Some`,
	-- otherwise return None
	-- @tparam function right_fn
	and_then: (right_fn)=>
		self if @is_none! else right_fn @data

	--- Return `right` if the variant is `None`, else return self's `Some`
	-- @param right
	or_other: (right)=>
		self if @is_some! else right

	--- Returns evaluated output of `right_fn` if the variant is `None`,
	-- otherwise returns self's `Some`
	-- @tparam function right_fn
	or_else: (right_fn)=>
		self if @is_some! else right_fn!

	--- Returns a `Some(value)` if either the self or the `right` have a
	-- `Some(value)`, but not both
	xor: (right)=>
		if (@is_some! and right\is_none!) or (@is_none! and right\is_some!)
			return @or_other right
		Option! -- None

	--- Transpose an Option of a Result into a Result of an Option
	transpose: =>
		if @is_none!
			return Ok self -- Result(None)
		@data.variant Option(@data.content)

class Entry
	new: (source, key)=>
		@source = source
		@key = key

	--- Determine whether or not a `key` exists currently in the table
	exists: => @source[@key] != nil

	--- Create a `default` value in the source if the key doesn't have an
	-- associated value already
	-- @param default
	or_insert: (default)=>
		source, key = @source, @key
		source[key] = default unless source[key]
		source[key]

	--- Create a default value from the result of `default_fn` in the source if
	-- the key doesn't have an associated value already
	-- @tparam function default_fn
	or_insert_with: (default_fn)=>
		source, key = @source, @key
		source[key] = default_fn! unless source[key]
		source[key]

	--- Apply a function `fn` to the entry, if it exists; should be called
	-- before returning the value, and can be chained
	-- @tparam function fn
	and_modify: (fn)=>
		source, key = @source, @key
		if source[key]
			source[key] = fn source[key]
		self

class Map
	new: (data={})=>
		@data = data

	--- Return an `Entry` to the potential value in the Map, which can be used
	-- to add a default value. If a default value isn't available or desired,
	-- instead use get()
	-- @param name
	entry: (key)=> Entry @data, key

	--- Returns `true` if a key exists within the table, or otherwise `false`
	contains_key: (key)=> @data[key] != nil

	--- Return an `Option<T>` to the potential value in the Map, which can be
	-- used to see if a value exists. If you want to insert a default value in
	-- the case it doesn't exist, use entry()
	get: (key)=> Option @data[key]

	--- Return a value expected to exist in the Map
	expect: (key)=> @get(key)\expect!

	--- Set a `value` in the Map to an associated `key`
	-- @param key
	-- @param value
	set: (key, value)=>
		@data[key] = value

	--- Remove a `key` from a Map
	remove: (key)=> @data[key] = nil

	--- Iterate over the Map
	iter: => pairs @data

return :Result, :Ok, :Err, :Option, :Entry, :Map
