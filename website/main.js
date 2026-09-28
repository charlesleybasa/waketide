// Fallback for browsers that don't support scroll-driven animations
if (!CSS.supports('(animation-timeline: view()) and (animation-range: entry)')) {
  console.log("Using JS fallback for scroll animations");
  
  // Parallax fallback
  const phoneMockup = document.querySelector('.phone-mockup');
  if (phoneMockup) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          window.addEventListener('scroll', onScroll);
        } else {
          window.removeEventListener('scroll', onScroll);
        }
      });
    }, { threshold: 0 });
    
    observer.observe(phoneMockup);
    
    function onScroll() {
      const scrollY = window.scrollY;
      const rect = phoneMockup.getBoundingClientRect();
      const elementTop = rect.top + scrollY;
      const windowHeight = window.innerHeight;
      
      if (scrollY >= elementTop - windowHeight && scrollY <= elementTop + rect.height) {
        const scrollPercent = (scrollY - (elementTop - windowHeight)) / (rect.height + windowHeight);
        
        // Translate from 100px to -100px
        const translateY = 100 - (scrollPercent * 200);
        // Rotate from 10deg to -5deg
        const rotateX = 10 - (scrollPercent * 15);
        
        phoneMockup.style.transform = `translateY(${translateY}px) rotateX(${rotateX}deg)`;
      }
    }
    
    onScroll();
  }
  
  // Entry fallback for text elements
  const observerEntry = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.style.opacity = 1;
          entry.target.style.transform = 'translateY(0)';
          observerEntry.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.2 }
  );

  document.querySelectorAll('.hero-title, .hero-subtitle, .app-store-btn').forEach((el) => {
    el.style.opacity = 0;
    el.style.transform = 'translateY(40px)';
    el.style.transition = 'opacity 0.8s ease-out, transform 0.8s ease-out';
    observerEntry.observe(el);
  });
}
