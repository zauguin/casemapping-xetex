#!/usr/bin/env texlua
kpse.set_program_name'lualatex'
function luaotfload_module() end
local unicode_data = require'luaotfload-unicode'

local mapping_tables = unicode_data.casemapping
local soft_dotted = unicode_data.soft_dotted
local ccc = unicode_data.ccc

local uppercase = mapping_tables.uppercase
local lowercase = mapping_tables.lowercase
local cased = mapping_tables.cased
local case_ignorable = mapping_tables.case_ignorable

uppercase[0x00DF]['de-xeszett'] = { _ = { 0x1E9E } }

for k,v in pairs(case_ignorable) do
  cased[k] = nil
end

local ccc230 = {}
local ccc0_230 = {}

for i=0, 0x10FFFF do
  local class = ccc[i] or 0
  if class == 230 or class == 0 then
    if class == 230 then
      ccc230[i] = true
    end
    ccc0_230[i] = true
  end
end

function gen_charclass(name, class)
  local line = string.format("Class [%s] = (", name)
  local run
  for i=0,0x110000 do
    if run then
      if not class[i] then
        line = string.format("%s U+%04X", line, run)
        if i ~= run + 1 then
          line = string.format("%s..U+%04X", line, i-1)
        end
        run = nil
      end
    elseif class[i] then
      run = i
    end
  end
  return line .. ' )'
end

function write_header(file, name, left_name)
  file:write(string.format('LHSName "%s"\n\z
  RHSName "%s"\n\n', left_name or 'UNICODE', 'anon' or name))
end

function write_pass_tex_text(file)
  file:write'\z
    pass(Unicode)\n\z
    \n\z
    ; ligatures from Knuth\'s original CMR fonts\n\z
    U+002D U+002D			<>	U+2013	; -- -> en dash\n\z
    U+002D U+002D U+002D	<>	U+2014	; --- -> em dash\n\z
    \n\z
    U+0027			<>	U+2019	; \' -> right single quote\n\z
    U+0027 U+0027	<>	U+201D	; \'\' -> right double quote\n\z
    U+0022			 >	U+201D	; " -> right double quote\n\z
    \n\z
    U+0060			<>	U+2018	; ` -> left single quote\n\z
    U+0060 U+0060	<>	U+201C	; `` -> left double quote\n\z
    \n\z
    U+0021 U+0060	<>	U+00A1	; !` -> inverted exclam\n\z
    U+003F U+0060	<>	U+00BF	; ?` -> inverted question\n\z
    \n\z
    ; additions supported in T1 encoding\n\z
    U+002C U+002C	<>	U+201E	; ,, -> DOUBLE LOW-9 QUOTATION MARK\n\z
    U+003C U+003C	<>	U+00AB	; << -> LEFT POINTING GUILLEMET\n\z
    U+003E U+003E	<>	U+00BB	; >> -> RIGHT POINTING GUILLEMET\n\z
  \n'
end
function write_pass(file, mapping, lang)
  file:write('pass(Unicode)\n\n')
  file:write(gen_charclass('cased', cased), '\n')
  file:write(gen_charclass('case_ignorable', case_ignorable), '\n')
  file:write(gen_charclass('ccc0_230', ccc0_230), '\n')
  file:write(gen_charclass('ccc230', ccc230), '\n')
  file:write(gen_charclass('soft_dotted', soft_dotted), '\n')
  file:write'\n'
  for source, t in pairs(mapping) do
    if tonumber(t) then
      file:write(string.format("U+%04X > U+%04X", source, t), '\n')
    else
      if t.Final_Sigma and t.Final_Sigma._ then
        local value = t.Final_Sigma._
        local mapped = string.format("U+%04X / [cased] [case_ignorable]* _ [case_ignorable]* ^[cased] >", source)
        for _, cp in ipairs(value) do
          mapped = string.format("%s U+%04X", mapped, cp)
        end
        file:write(mapped, '\n')
      end
      -- Missing: Other contexts
      local value = t._
      if t[lang] then
        local l = t[lang]
        if l.After_Soft_Dotted then
          local value = l.After_Soft_Dotted._
          assert(value)
          local mapped = string.format("U+%04X / [soft_dotted] ^[ccc0_230]* _ >", source)
          for _, cp in ipairs(value) do
            mapped = string.format("%s U+%04X", mapped, cp)
          end
          file:write(mapped, '\n')
        end
        if l.More_Above then
          local value = l.More_Above._
          assert(value)
          local mapped = string.format("U+%04X / _ ^[ccc0_230]* [ccc230] >", source)
          for _, cp in ipairs(value) do
            mapped = string.format("%s U+%04X", mapped, cp)
          end
          file:write(mapped, '\n')
        end
        if l.Not_Before_Dot then
          local value = l.Not_Before_Dot._
          assert(value)
          local mapped = string.format("U+%04X / _ ^[ccc0_230]* ^U+0307 >", source)
          for _, cp in ipairs(value) do
            mapped = string.format("%s U+%04X", mapped, cp)
          end
          file:write(mapped, '\n')
        end
        if l.After_I then
          local value = l.After_I._
          assert(value)
          local mapped = string.format("U+%04X / U+0049 ^[ccc0_230]* _ >", source)
          for _, cp in ipairs(value) do
            mapped = string.format("%s U+%04X", mapped, cp)
          end
          file:write(mapped, '\n')
        end
        value = l._ or value
      end
      if value then
        local mapped = string.format("U+%04X >", source)
        for _, cp in ipairs(value) do
          mapped = string.format("%s U+%04X", mapped, cp)
        end
        file:write(mapped, '\n')
      end
    end
  end
end
function write_pass_remove_greek_diacritics(file, alt_iota)
  file:write('\n\z
    pass(Unicode)\n\z
    Class [greek] = ( U+0370..U+03FF U+1F00..U+1FFF U+2126 )\n\z
    Class [vowels_gaining_dialytika] = (U+0399 U+03A5)\n\z
    Class [vowels] = ( U+0391 U+0395 U+0397 U+0399 U+039F U+03A5 U+03A9 )\n\z
    Class [other_diacritic] = ( U+0304 U+0306 U+0313 U+0314 U+0343 )\n\z
    Class [accent] = ( U+0300 U+0301 U+0302 U+0303 U+0311 U+0342 )\n\z
    Define ypogegrammeni U+0345\n\z
    Define dialytika U+0308\n\z
    \n\z
    U+0397 [other_diacritic]* [accent] / # _ # > U+0397 U+0301\n\z
    [accent] >\n\z
    [other_diacritic] >\n\z
    [vowels]=first [other_diacritic]* [accent] ([other_diacritic] | [accent])* [vowels_gaining_dialytika]=second ([other_diacritic] | [accent])* dialytika? > @first @second dialytika\n\z
  ')
  if not alt_iota then
    file:write'ypogegrammeni > U+0399\n'
  end
end

function write_teckit(name, mapping, lang, tex_text)
  local file = assert(io.open(name .. '.map', 'w'))
  write_header(file, name, tex_text and 'TeX-text' or 'UNICODE')
  if tex_text then write_pass_tex_text(file) end
  write_pass(file, mapping, lang)
  file:close()
  assert(0 == os.spawn{'teckit_compile', name .. '.map'})
end
function write_greek_upper(name, mapping, alt_iota, tex_text)
  local new_mapping = {}
  for k,v in next, mapping do new_mapping[k] = v end
  new_mapping[0x0345] = nil

  local file = assert(io.open(name .. '.map', 'w'))
  write_header(file, name, tex_text and 'TeX-text' or 'UNICODE')
  file:write('\z
    LHSFlags(ExpectsNFD)\n\z
    RHSFlags(GeneratesNFD)\n\z
  \n')
  if tex_text then write_pass_tex_text(file) end
  write_pass(file, new_mapping, lang)
  write_pass_remove_greek_diacritics(file, alt_iota)
  file:close()
  assert(0 == os.spawn{'teckit_compile', name .. '.map'})
end
write_teckit('upper', uppercase, nil)
write_teckit('upper_tex-text', uppercase, nil, true)
write_teckit('lower', lowercase, nil)
write_teckit('lower_tex-text', lowercase, nil, true)
write_teckit('upper_lt', uppercase, 'lt')
write_teckit('upper_lt_tex-text', uppercase, 'lt', true)
write_teckit('lower_lt', lowercase, 'lt')
write_teckit('lower_lt_tex-text', lowercase, 'lt', true)
-- az and tr use the same tailoring
write_teckit('upper_aztr', uppercase, 'tr')
write_teckit('upper_aztr_tex-text', uppercase, 'tr', true)
write_teckit('lower_aztr', lowercase, 'tr')
write_teckit('lower_aztr_tex-text', lowercase, 'tr', true)
-- write_teckit('upper_az', uppercase, 'az')
-- write_teckit('upper_az_tex-text', uppercase, 'az', true)
-- write_teckit('lower_az', lowercase, 'az')
-- write_teckit('lower_az_tex-text', lowercase, 'az', true)
write_greek_upper('upper_el', uppercase, false)
write_greek_upper('upper_el_tex-text', uppercase, false, true)
-- write_greek_upper('lower_el', uppercase, false)
-- write_greek_upper('lower_el_tex-text', uppercase, false, true)
-- lower_el is the same as lower

-- The two variants only apply to uppercase mappings
write_greek_upper('upper_el-xiota', uppercase, true)
write_greek_upper('upper_el-xiota_tex-text', uppercase, true, true)
write_teckit('upper_de-xeszett', uppercase, 'de-xeszett')
write_teckit('upper_de-xeszett_tex-text', uppercase, 'de-xeszett', true)
