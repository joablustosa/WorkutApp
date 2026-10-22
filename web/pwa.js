// Ponte entre o navegador e o app: splash, convite de instalacao e o aviso
// de iOS. Tudo que depende de API do navegador (e nao existe dentro do
// Flutter) mora aqui.
(function () {
  'use strict';

  var DISMISS_KEY = 'workut.install.dismissed';

  var splash = document.getElementById('workut-splash');
  var banner = document.getElementById('workut-install');
  var hint = document.getElementById('workut-install-hint');
  var action = document.getElementById('workut-install-action');
  var dismiss = document.getElementById('workut-install-dismiss');

  var deferredPrompt = null;

  // ---------------------------------------------------------------- cache

  if ('serviceWorker' in navigator) {
    // Se ja havia um service worker controlando a pagina, uma troca de
    // controlador significa que entrou versao nova do app.
    var hadController = !!navigator.serviceWorker.controller;

    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function (error) {
        console.warn('Service worker nao registrado:', error);
      });
    });

    navigator.serviceWorker.addEventListener('controllerchange', function () {
      if (!hadController) return;
      hadController = false;
      showUpdateToast();
    });
  }

  function showUpdateToast() {
    if (document.getElementById('workut-update')) return;

    var toast = document.createElement('div');
    toast.id = 'workut-update';
    toast.innerHTML =
      '<span>Nova versao do Workut disponivel.</span>' +
      '<button type="button">Atualizar</button>';
    toast.querySelector('button').addEventListener('click', function () {
      window.location.reload();
    });
    document.body.appendChild(toast);
  }

  function hideSplash() {
    if (!splash) return;
    splash.classList.add('is-gone');
    window.setTimeout(function () {
      if (splash && splash.parentNode) splash.parentNode.removeChild(splash);
      splash = null;
    }, 320);
  }

  // O Flutter avisa quando pintou a primeira tela; se algo der errado no
  // carregamento, o timeout tira o splash para nao deixar a pagina travada.
  window.addEventListener('flutter-first-frame', hideSplash);
  window.setTimeout(hideSplash, 12000);

  function isStandalone() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true
    );
  }

  function isIos() {
    return (
      /iphone|ipad|ipod/i.test(window.navigator.userAgent) ||
      // iPad moderno se anuncia como Mac; o toque denuncia.
      (window.navigator.platform === 'MacIntel' &&
        window.navigator.maxTouchPoints > 1)
    );
  }

  function wasDismissed() {
    try {
      return window.localStorage.getItem(DISMISS_KEY) === '1';
    } catch (error) {
      return false;
    }
  }

  function remember() {
    try {
      window.localStorage.setItem(DISMISS_KEY, '1');
    } catch (error) {
      /* navegador sem storage: tudo bem, o convite volta na proxima visita */
    }
  }

  function openBanner() {
    if (!banner || isStandalone() || wasDismissed()) return;
    banner.classList.add('is-open');
  }

  function closeBanner() {
    if (banner) banner.classList.remove('is-open');
  }

  // Android / Chrome / Edge: o navegador entrega o convite nativo.
  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    // Espera o app aparecer antes de convidar.
    window.setTimeout(openBanner, 2500);
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    closeBanner();
    remember();
  });

  if (action) {
    action.addEventListener('click', function () {
      if (!deferredPrompt) {
        closeBanner();
        return;
      }
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(function () {
        deferredPrompt = null;
        closeBanner();
      });
    });
  }

  if (dismiss) {
    dismiss.addEventListener('click', function () {
      closeBanner();
      remember();
    });
  }

  // iOS nao tem `beforeinstallprompt`: a instalacao e manual pelo menu
  // Compartilhar, entao o banner vira instrucao.
  if (isIos() && !isStandalone() && !wasDismissed()) {
    if (hint) {
      hint.textContent = 'Toque em Compartilhar e depois em "Adicionar a Tela de Inicio".';
    }
    if (action) action.style.display = 'none';
    window.setTimeout(openBanner, 3500);
  }
})();
