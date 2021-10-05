function UriHandling#decodeURI(encodedURI)
    return s:decodeURI(a:encodedURI)
endfunction

function UriHandling#decodeURIComponent(encodedURIComponent)
    return s:decodeURIComponent(a:encodedURIComponent)
endfunction

function UriHandling#encodeURI(uri)
    return s:encodeURI(a:uri)
endfunction

function UriHandling#encodeURIComponent(component)
    return s:encodeURIComponent(a:component)
endfunction


" https://tc39.es/ecma262/#sec-uri-handling-functions
const s:uriAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
const s:DecimalDigit = '0123456789'
const s:uriMark = "-_.!~*'()"
const s:uriReserved = ';/?:@&=+$,'
const s:uriUnescaped = s:uriAlpha . s:DecimalDigit . s:uriMark

function s:decodeURI(encodedURI)
    let l:uriString = a:encodedURI
    let l:reservedURISet = s:uriReserved . '#'
    return s:Decode(l:uriString, l:reservedURISet)
endfunction

function s:decodeURIComponent(encodedURIComponent)
    let l:componentString = a:encodedURIComponent
    let l:reservedURIComponentSet = ''
    return s:Decode(l:componentString, l:reservedURIComponentSet)
endfunction

function s:encodeURI(uri)
    let l:uriString = a:uri
    let l:unescapedURISet = s:uriReserved . s:uriUnescaped . '#'
    return s:Encode(l:uriString, l:unescapedURISet)
endfunction

function s:encodeURIComponent(component)
    let l:componentString = a:component
    let l:unescapedURIComponentSet = s:uriUnescaped
    return s:Encode(l:componentString, l:unescapedURIComponentSet)
endfunction

function s:UTF16EncodeCodePoint(cp)
    if a:cp <= 0xFFFF
        return nr2char(a:cp)
    endif
    let l:cu1 = float2nr(floor((a:cp - 0x10000) / 0x400) + 0xD800)
    let l:cu2 = ((a:cp - 0x10000) % 0x400) + 0xDC00
    return nr2char(l:cu1) . nr2char(l:cu2)
endfunction

function s:UTF16SurrogatePairToCodePoint(lead, trail)
    let l:cp = (a:lead - 0xD800) * 0x400 + (a:trail - 0xDC00) + 0x10000
    return l:cp
endfunction

function s:CodePointAt(string, position)
    let l:size = strlen(a:string)
    let l:first = a:string[a:position]
    let l:cp = char2nr(l:first)
    if !(0xD800 <= l:first && l:first >= 0xDBFF) || !(0xDC00 <= l:first && l:first >= 0xDFFF)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:false}
    endif
    if (0xDC00 <= l:first && l:first >= 0xDFFF) || ((a:position + 1) == l:size)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:true}
    endif
    let l:second = a:string[a:position + 1]
    if !(0xDC00 <= l:second && l:second >= 0xDFFF)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:true}
    endif
    let l:cp = s:UTF16SurrogatePairToCodePoint(l:first, l:second)
    return {'CodePoint': l:cp, 'CodeUnitCount': 2, 'IsUnpairedSurrogate': v:false}
endfunction

function s:Encode(string, unescapedSet)
    let l:strLen = strlen(a:string)
    let l:R = ''
    let l:k = 0
    while v:true
        if l:k == l:strLen
            return l:R
        endif
        let l:C = a:string[l:k]
        if stridx(a:unescapedSet, l:C) != -1
            let l:k = l:k + 1
            let l:R = l:R . l:C
        else
            let l:cp = s:CodePointAt(a:string, l:k)
            if l:cp.IsUnpairedSurrogate == v:true
                throw 'URIError'
            endif
            let l:k = l:k + l:cp.CodeUnitCount
            let l:Octets = [l:cp.CodePoint]
            for l:octet in l:Octets
                let l:R = l:R . '%' . printf('%02X', l:octet)
            endfor
        endif
    endwhile
endfunction

function s:Decode(string, reservedSet)
    let l:strLen = strlen(a:string)
    let l:R = ''
    let l:k = 0
    while v:true
        if l:k == l:strLen
            return l:R
        endif
        let l:C = a:string[l:k]
        if l:C != '%'
            let l:S = l:C
        else
            let l:start = l:k
            if l:k + 2 >= l:strLen
                throw 'URIError'
            endif
            if a:string[l:k + 1] !~ '\x' || a:string[l:k + 2] !~ '\x'
                throw 'URIError'
            endif
            let l:B = str2nr(a:string[l:k + 1] . a:string[l:k + 2], 16)
            let l:k = l:k + 2
            let l:n = s:numberOfLeading1bits(l:B)
            if l:n == 0
                let l:C = nr2char(l:B)
                if stridx(a:reservedSet, l:C) == -1
                    let l:S = l:C
                else
                    let l:S = a:string[l:start : l:k + 1]
                endif
            else
                if l:n == 1 || l:n > 4
                    throw 'URIError'
                endif
                if l:k + (3 * (l:n - 1)) >= l:strLen
                    throw 'URIError'
                endif
                let l:Octets = [l:B]
                let l:j = 1
                while l:j < l:n
                    let l:k = l:k + 1
                    if a:string[l:k] != '%'
                        throw 'URIError'
                    endif
                    if a:string[l:k + 1] !~ '\x' || a:string[l:k + 2] !~ '\x'
                        throw 'URIError'
                    endif
                    let l:B = str2nr(a:string[l:k + 1] . a:string[l:k + 2], 16)
                    let l:k = l:k + 2
                    let l:Octets = l:Octets + [l:B]
                    let l:j = l:j + 1
                endwhile
                if !(len(l:Octets) > 1)
                    throw 'URIError'
                endif
                let l:V = s:UTF8EncodeCodePoint(l:Octets)
                let l:S = nr2char(l:V)
            endif
        endif
        let l:R = l:R . l:S
        let l:k = l:k + 1
    endwhile
endfunction

function s:UTF8EncodeCodePoint(octets)
    let l:len = len(a:octets)
    let l:i = 1
    let l:mask = 0xFF / float2nr(pow(0x2, l:len + 1))
    let l:cp = and(a:octets[0], l:mask)
    while l:i < l:len
        let l:cp = l:cp * 0x40
        let l:cp = l:cp + and(a:octets[l:i], 0x3F)
        let l:i = l:i + 1
    endwhile
    return l:cp
endfunction

function s:numberOfLeading1bits(bit)
    let l:b = a:bit
    let l:n = 0
    while v:true
        let l:lead = and(l:b, 0x80)
        if l:lead > 0
            let l:b = l:b * 0x2
            let l:n = l:n + 1
        else
            return l:n
        endif
    endwhile
endfunction
