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

function write_header(file, name)
  file:write(string.format('LHSName "UNICODE"\n\z
  RHSName "%s"\n\n', name))
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
function write_teckit(name, mapping, lang)
  local file = assert(io.open(name .. '.map', 'w'))
  write_header(file, name)
  write_pass(file, mapping, lang)
  file:close()
  os.spawn('teckit_compile', name .. '.map')
end
write_teckit('upper', uppercase)
write_teckit('lower', lowercase)
write_teckit('upper_lt', uppercase, 'lt')
write_teckit('lower_lt', lowercase, 'lt')
write_teckit('upper_tr', uppercase, 'tr')
write_teckit('lower_tr', lowercase, 'tr')
write_teckit('upper_az', uppercase, 'az')
write_teckit('lower_az', lowercase, 'az')
