/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

*****/

#ifndef RETRO80_DASM_H
#define RETRO80_DASM_H
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

std::pair<std::vector<std::optional<uint8_t>>, std::string> dasm(uint16_t addr, const std::function<std::optional<uint8_t>(uint16_t)>& read, bool z80 = false);
std::vector<uint8_t> assembly(std::string_view source);

#endif //RETRO80_DASM_H
