(() => {
  document.documentElement.classList.add('js');

  // GitHub Pages gives us the owner and repository in the URL. Point every
  // repository link there automatically, with a sensible local fallback.
  const isPages = location.hostname.endsWith('.github.io');
  if (isPages) {
    const owner = location.hostname.split('.')[0];
    const pathParts = location.pathname.split('/').filter(Boolean);
    const repo = pathParts[0] || 'fitr';
    document.querySelectorAll('[data-github]').forEach((link) => {
      link.href = `https://github.com/${owner}/${repo}`;
    });
  }

  document.getElementById('year').textContent = String(new Date().getFullYear());

  // Mobile navigation
  const toggle = document.querySelector('.nav-toggle');
  const links = document.getElementById('nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', () => {
      const open = links.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', String(open));
    });
    links.addEventListener('click', (event) => {
      if (event.target.closest('a')) {
        links.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // Screenshot carousel
  document.querySelectorAll('[data-carousel]').forEach((root) => {
    const slides = Array.from(root.querySelectorAll('.slide'));
    const dots = Array.from(root.querySelectorAll('[data-carousel-dot]'));
    const caption = root.parentElement.querySelector('.phone-caption');
    const prev = root.querySelector('[data-carousel-prev]');
    const next = root.querySelector('[data-carousel-next]');
    if (!slides.length) return;

    let index = 0;
    let timer = null;
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function show(nextIndex) {
      index = (nextIndex + slides.length) % slides.length;
      slides.forEach((slide, i) => slide.classList.toggle('is-active', i === index));
      dots.forEach((dot, i) => {
        dot.classList.toggle('is-active', i === index);
        dot.setAttribute('aria-selected', String(i === index));
      });
      if (caption) caption.textContent = slides[index].dataset.caption || '';
    }

    function start() {
      if (reduceMotion) return;
      stop();
      timer = window.setInterval(() => show(index + 1), 5200);
    }

    function stop() {
      if (timer) window.clearInterval(timer);
      timer = null;
    }

    dots.forEach((dot, i) => {
      dot.addEventListener('click', () => {
        show(i);
        start();
      });
    });
    prev?.addEventListener('click', () => {
      show(index - 1);
      start();
    });
    next?.addEventListener('click', () => {
      show(index + 1);
      start();
    });
    root.addEventListener('mouseenter', stop);
    root.addEventListener('mouseleave', start);
    root.addEventListener('focusin', stop);
    root.addEventListener('focusout', start);

    show(0);
    start();
  });

  // Scroll reveal
  const revealTargets = document.querySelectorAll('[data-reveal]');
  if ('IntersectionObserver' in window && revealTargets.length) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.08 }
    );
    revealTargets.forEach((target) => observer.observe(target));
  } else {
    revealTargets.forEach((target) => target.classList.add('is-visible'));
  }

  // Keep only one FAQ item open at a time.
  const details = document.querySelectorAll('.faq details');
  details.forEach((item) => {
    item.addEventListener('toggle', () => {
      if (!item.open) return;
      details.forEach((other) => {
        if (other !== item) other.open = false;
      });
    });
  });
})();
