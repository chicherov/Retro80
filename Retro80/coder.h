/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

#ifndef RETRO80_CODER_H
#define RETRO80_CODER_H
#include <concepts>
#include <vector>
#include <span>

#include <stdexcept>

template<typename T>
concept Encodable = requires(const T &object, struct Encoder &encoder)
{
	object.encode(encoder);
};

struct Encoder : public std::vector<char>
{
	void write(const void *p, size_t n)
	{
		std::copy((const char *) p, (const char *) p + n, std::back_inserter(*this));
	}

	template<typename T>
	requires std::is_arithmetic_v<T> || std::is_enum_v<T>
	Encoder &encode(const T &value)
	{
		write(&value, sizeof(T));
		return *this;
	}

	Encoder &encode(const Encodable auto &value)
	{
		value.encode(*this);
		return *this;
	}

	template<typename T, typename... V>
	Encoder &encode(const T &value, V &&... args)
	{
		return encode(value).encode(std::forward<V>(args)...);
	}

	template<typename T>
	Encoder &operator<<(const T &value)
	{
		return encode(value);
	}

#ifdef __OBJC__
	auto dataObject()
	{
		return [NSData dataWithBytes:data() length:size()];
	}
#endif

};

template<typename T>
concept Decodable = requires(T &object, struct Decoder &decoder)
{
	object.decode(decoder);
};

struct Decoder : public std::span<const char>
{
	size_t pos = 0;

	Decoder(const void *p, size_t n) : std::span<const char>((const char *) p, n)
	{
	}

#ifdef __OBJC__
	Decoder(NSData *data): Decoder(data.bytes, data.length)
	{
	}
#endif

	void read(void *p, size_type n)
	{
		if(pos + n > size())
			throw std::out_of_range("Decoder");

		std::copy(data() + pos, data() + pos + n, (char *) p);
		pos += n;
	}

	template<typename T>
	requires std::is_arithmetic_v<T> || std::is_enum_v<T>
	Decoder &decode(T &value)
	{
		read(&value, sizeof(T));
		return *this;
	}

	Decoder &decode(Decodable auto &value)
	{
		value.decode(*this);
		return *this;
	}

	template<typename T, typename... V>
	Decoder &decode(T &value, V &&... args)
	{
		return decode(value).decode(std::forward<V>(args)...);
	}

	template<typename T>
	Decoder &operator>>(T &value)
	{
		return decode(value);
	}
};

#define Searialize(...) \
	void encode(Encoder &encoder) const	{ encoder.encode(__VA_ARGS__); }	\
	void decode(Decoder &decoder) { decoder.decode(__VA_ARGS__); }

#endif //RETRO80_CODER_H
