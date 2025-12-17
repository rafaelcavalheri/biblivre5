(function(){
  function parseLocal(val){
    if (val == null) return null;
    if (val instanceof Date) return val;
    if (typeof val === "number") return new Date(val);
    if (typeof val !== "string") return new Date(val);
    var s = val.trim();
    var m = s.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$/);
    if (m) {
      return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]||0));
    }
    return new Date(s.replace(" ", "T"));
  }
  function _formatDate(val, fmt){
    var d = parseLocal(val);
    if (!d || isNaN(d)) return val;
    var opts = (fmt === "D")
      ? { year:"numeric", month:"long", day:"numeric", weekday:"long", timeZone:"America/Sao_Paulo" }
      : { year:"numeric", month:"long", day:"numeric", weekday:"long", hour:"2-digit", minute:"2-digit", timeZone:"America/Sao_Paulo" };
    try { return new Intl.DateTimeFormat("pt-BR", opts).format(d); } catch(e){ return d.toLocaleString("pt-BR"); }
  }
  window._d = _formatDate;
})();
