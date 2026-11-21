/* =====================================================================
   Rise Hub · comportamento compartilhado das páginas de serviço
   - Nav: classe .is-scrolled ao rolar
   - Entrada suave (.reveal -> .in) com fallback que mostra tudo
   - Pixel Meta + API de Conversões com eventID por evento (padrão de paginas.html)
     O init do Pixel e o PageView ficam inline no <head> de cada página.
     Aqui saem: ViewContent, o par PageView/ViewContent pelo servidor e Contact
     no clique de qualquer link do WhatsApp.
   - Links para /form herdam utm_* e fbclid de quem chegou por anúncio
   - FAQ: um item aberto por vez dentro de cada .faq
   - CTA fixo no mobile (#sticky), ano no rodapé ([data-year])
   Sem dependências. Carregar com <script src="/assets/servico.js?v=1" defer>.
   ===================================================================== */
(function () {
  'use strict';

  var SLUG = (document.body && document.body.dataset.slug) || location.pathname.replace(/^\/|\.html$/g, '') || 'home';

  // ---------- Rastreamento ----------
  if (typeof window.rhEventId !== 'function') {
    window.rhEventId = function (prefix) {
      return prefix + '_' + Date.now() + '_' + Math.random().toString(36).slice(2, 10);
    };
  }

  function cookie(name) {
    var m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
    return m ? decodeURIComponent(m[1]) : null;
  }

  // Envia pelo servidor (/api/meta-capi guarda o token; nada de segredo no navegador)
  function sendCapi(name, eventId, customData) {
    var userData = { client_user_agent: navigator.userAgent };
    var fbp = cookie('_fbp');
    var fbc = cookie('_fbc');
    if (fbp) userData.fbp = fbp;
    if (fbc) userData.fbc = fbc;
    var event = {
      event_name: name,
      event_time: Math.floor(Date.now() / 1000),
      event_id: eventId,
      event_source_url: location.href,
      action_source: 'website',
      user_data: userData
    };
    if (customData) event.custom_data = customData;
    try {
      fetch('/api/meta-capi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: [event] }),
        keepalive: true // o clique no WhatsApp sai da página; keepalive deixa o envio terminar
      }).catch(function () { /* rede ou bloqueador: o Pixel do navegador continua valendo */ });
    } catch (e) { /* idem */ }
  }

  // Dispara no Pixel e no servidor com o mesmo eventID (a Meta conta uma vez só)
  function rhTrack(name, params, eventId) {
    var id = eventId || window.rhEventId(name.toLowerCase());
    try { if (window.fbq) window.fbq('track', name, params || {}, { eventID: id }); } catch (e) { /* bloqueador */ }
    sendCapi(name, id, params);
    return id;
  }
  window.rhTrack = rhTrack;

  // ViewContent logo após o PageView do <head>
  var viewParams = { content_name: SLUG, content_type: 'service' };
  var viewContentId = window.rhEventId('vc');
  try { if (window.fbq) window.fbq('track', 'ViewContent', viewParams, { eventID: viewContentId }); } catch (e) { /* bloqueador */ }

  // Par do PageView e do ViewContent pelo servidor. Espera o Pixel gravar o _fbp
  // para a Meta conseguir casar navegador e servidor.
  (function sendInitialCapi() {
    var tries = 0;
    var timer = setInterval(function () {
      tries += 1;
      if (!cookie('_fbp') && tries < 8) return;
      clearInterval(timer);
      if (window.rhPageViewId) sendCapi('PageView', window.rhPageViewId);
      sendCapi('ViewContent', viewContentId, viewParams);
    }, 400);
  })();

  // Contact em qualquer link do WhatsApp (delegado: vale para links criados depois)
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href*="wa.me"]');
    if (!a) return;
    rhTrack('Contact', { content_name: SLUG, content_category: a.dataset.cta || 'whatsapp' });
  });

  // ---------- Links para o /form herdam a origem do anúncio ----------
  (function forwardCampaign() {
    var from = new URLSearchParams(location.search);
    var keep = [];
    from.forEach(function (value, key) {
      if (/^(utm_|fbclid$)/.test(key)) keep.push([key, value]);
    });
    if (!keep.length) return;
    var hasUtm = keep.some(function (kv) { return kv[0].indexOf('utm_') === 0; });
    document.querySelectorAll('a[href^="/form"]').forEach(function (a) {
      var url;
      try { url = new URL(a.getAttribute('href'), location.origin); } catch (err) { return; }
      // Se o visitante veio com utm, a origem dele vale mais que a utm fixa do site
      if (hasUtm) {
        Array.from(url.searchParams.keys()).forEach(function (k) {
          if (k.indexOf('utm_') === 0) url.searchParams.delete(k);
        });
      }
      keep.forEach(function (kv) { url.searchParams.set(kv[0], kv[1]); });
      if (!url.searchParams.has('utm_content')) url.searchParams.set('utm_content', SLUG);
      a.setAttribute('href', url.pathname + url.search + url.hash);
    });
  })();

  // ---------- Nav ao rolar ----------
  var nav = document.querySelector('.nav');
  if (nav) {
    var ticking = false;
    var syncNav = function () {
      nav.classList.toggle('is-scrolled', window.scrollY > 8);
      ticking = false;
    };
    window.addEventListener('scroll', function () {
      if (!ticking) { ticking = true; window.requestAnimationFrame(syncNav); }
    }, { passive: true });
    syncNav();
  }

  // ---------- Entrada suave ----------
  var items = document.querySelectorAll('.reveal');
  var showAll = function () { items.forEach(function (el) { el.classList.add('in'); }); };
  if (!('IntersectionObserver' in window)) {
    showAll();
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    items.forEach(function (el) { io.observe(el); });
    // Âncora direta (ex.: /servicos#rise-engine): garante que o alvo apareça
    window.addEventListener('load', function () {
      if (!location.hash) return;
      var target = document.getElementById(location.hash.slice(1));
      if (!target) return;
      var holder = target.closest('.reveal') || target;
      holder.classList.add('in');
      target.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('in'); });
    });
  }

  // ---------- FAQ: um aberto por vez ----------
  document.querySelectorAll('.faq').forEach(function (group) {
    var all = group.querySelectorAll('details');
    all.forEach(function (d) {
      d.addEventListener('toggle', function () {
        if (!d.open) return;
        all.forEach(function (other) { if (other !== d) other.open = false; });
      });
    });
  });

  // ---------- CTA fixo no mobile ----------
  var sticky = document.getElementById('sticky');
  var heroCta = document.querySelector('.hero .btn');
  var closeSec = document.querySelector('.close');
  if (sticky && heroCta && 'IntersectionObserver' in window) {
    var heroGone = false;
    var closeVisible = false;
    var syncSticky = function () {
      var on = heroGone && !closeVisible;
      sticky.classList.toggle('on', on);
      // Fora da tela, sai da ordem de foco e do leitor de tela
      if (on) { sticky.removeAttribute('inert'); sticky.removeAttribute('aria-hidden'); }
      else { sticky.setAttribute('inert', ''); sticky.setAttribute('aria-hidden', 'true'); }
    };
    syncSticky();
    new IntersectionObserver(function (e) { heroGone = !e[0].isIntersecting; syncSticky(); }).observe(heroCta);
    if (closeSec) {
      new IntersectionObserver(function (e) { closeVisible = e[0].isIntersecting; syncSticky(); }, { threshold: 0.2 }).observe(closeSec);
    }
  }

  // ---------- Ano no rodapé ----------
  document.querySelectorAll('[data-year]').forEach(function (el) {
    el.textContent = String(new Date().getFullYear());
  });
})();
