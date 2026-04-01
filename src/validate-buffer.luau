return function(b:any,refs:{unknown}?)
    return typeof(b)=="buffer" and buffer.len(b)>0 and (refs and typeof(refs)=="table");
end
