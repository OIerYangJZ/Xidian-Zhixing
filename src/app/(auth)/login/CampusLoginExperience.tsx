'use client';

import { signIn } from 'next-auth/react';
import { PointerEvent as ReactPointerEvent, useCallback, useEffect, useRef, useState } from 'react';

const campusImages = [
  {
    src: '/campus-login/campus-courtyard.png',
    alt: '长安校区中心广场与教学楼',
    title: '把目光放远',
    place: '长安校区 · 中心广场',
  },
  {
    src: '/campus-login/campus-stone.png',
    alt: '西电校名石与校园松林',
    title: '从这里出发',
    place: '西电校名石',
  },
  {
    src: '/campus-login/campus-clock.png',
    alt: '校园主楼与远山',
    title: '让时间留下回响',
    place: '校园主楼 · 晨光',
  },
  {
    src: '/campus-login/campus-library.png',
    alt: '图书馆与校园秋色',
    title: '在书页之间相遇',
    place: '图书馆 · 秋日',
  },
];

export function CampusLoginExperience() {
  const frameRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [loading, setLoading] = useState(false);
  const [authError, setAuthError] = useState('');
  const activeImage = campusImages[activeIndex];

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const updateMotionPreference = () => setReducedMotion(media.matches);
    updateMotionPreference();
    media.addEventListener('change', updateMotionPreference);
    return () => media.removeEventListener('change', updateMotionPreference);
  }, []);

  useEffect(() => {
    const query = new URLSearchParams(window.location.search);
    const attemptId = query.get('attempt');
    const errorCode = query.get('xidianError');
    if (!attemptId) {
      if (errorCode) setAuthError('学校统一认证未完成，请重新登录。');
      return undefined;
    }

    let active = true;
    let timer: number | undefined;
    setLoading(true);
    const poll = async () => {
      try {
        const response = await fetch(`/api/auth/xidian/session/${encodeURIComponent(attemptId)}`, {
          cache: 'no-store',
        });
        const result = await response.json();
        if (!active) return;
        const status = result?.data?.status;
        if (status === 'approved') {
          const signedIn = await signIn('xidian-attempt', {
            attemptId,
            callbackUrl: result.data.callbackUrl || '/feed',
            redirect: false,
          });
          if (signedIn?.ok && signedIn.url) window.location.assign(signedIn.url);
          else {
            setAuthError('登录状态已失效，请重新登录。');
            setLoading(false);
          }
          return;
        }
        if (status === 'pending') {
          timer = window.setTimeout(poll, 1000);
          return;
        }
        setAuthError('学校统一认证已失效，请重新登录。');
        setLoading(false);
      } catch {
        if (!active) return;
        setAuthError('暂时无法确认登录状态，请重新登录。');
        setLoading(false);
      }
    };
    poll();
    return () => {
      active = false;
      if (timer) window.clearTimeout(timer);
    };
  }, []);

  useEffect(() => {
    if (reducedMotion || paused) return undefined;
    const timer = window.setInterval(() => setActiveIndex((index) => (index + 1) % campusImages.length), 5200);
    return () => window.clearInterval(timer);
  }, [activeIndex, paused, reducedMotion]);

  const moveSlide = useCallback((amount: number) => {
    setActiveIndex((index) => (index + amount + campusImages.length) % campusImages.length);
  }, []);

  const onPointerMove = useCallback((event: ReactPointerEvent<HTMLDivElement>) => {
    if (event.pointerType !== 'mouse' || !frameRef.current) return;
    const bounds = frameRef.current.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - 0.5;
    const y = (event.clientY - bounds.top) / bounds.height - 0.5;
    const image = frameRef.current.querySelector<HTMLElement>('.is-active');
    image?.style.setProperty('--pan-x', `${x * -10}px`);
    image?.style.setProperty('--pan-y', `${y * -8}px`);
  }, []);

  const resetPointer = useCallback(() => {
    frameRef.current?.querySelectorAll<HTMLElement>('.campus-login__image').forEach((image) => {
      image.style.setProperty('--pan-x', '0px');
      image.style.setProperty('--pan-y', '0px');
    });
  }, []);

  const login = useCallback(async () => {
    setLoading(true);
    setAuthError('');
    const callbackUrl = new URLSearchParams(window.location.search).get('from') || '/feed';
    const useLocalAccount = process.env.NODE_ENV !== 'production' && process.env.NEXT_PUBLIC_LOCAL_TEST_AUTH === 'true';
    if (useLocalAccount) {
      try {
        const result = await signIn('local-test', { callbackUrl, redirect: false });
        if (!result?.ok || !result.url) throw new Error('local_login_failed');
        window.location.assign(result.url);
      } catch {
        setAuthError('本地登录暂不可用，请检查开发数据库是否已启动。');
        setLoading(false);
      }
      return;
    }
    try {
      const response = await fetch('/api/auth/xidian/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callbackUrl }),
      });
      const result = await response.json();
      if (!response.ok || !result?.data?.authorizeUrl) throw new Error('auth_setup_failed');
      window.location.assign(result.data.authorizeUrl);
    } catch {
      setAuthError('学校统一认证暂时不可用，请稍后重试。');
      setLoading(false);
    }
  }, []);

  return (
    <main className="campus-login">
      <header className="campus-login__topbar">
        <a className="campus-login__brand" href="/feed" aria-label="进入知行信息流">
          <img className="campus-login__brand-logo" src="/campus-login/zhixing-logo.jpg" alt="" />
          <span>西电知行</span>
        </a>
        <nav className="campus-login__top-links" aria-label="登录页导航">
          <a href="#campus-gallery">认识校园</a>
          <a href="#campus-auth">统一认证</a>
        </nav>
      </header>

      <div className="campus-login__layout">
        <section
          ref={frameRef}
          className="campus-login__story"
          aria-labelledby="campus-login-title"
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => setPaused(false)}
          onPointerMove={onPointerMove}
          onPointerLeave={resetPointer}>
          {campusImages.map((image, index) => (
            <img
              key={image.src}
              className={`campus-login__image${activeIndex === index ? 'is-active' : ''}`}
              src={image.src}
              alt={image.alt}
              aria-hidden={index !== activeIndex}
              loading={index === 0 ? 'eager' : 'lazy'}
            />
          ))}
          <div className="campus-login__story-grid" aria-hidden="true" />
          <div className="campus-login__intro">
            <div className="campus-login__intro-title">
              <p className="campus-login__eyebrow">XIDIAN UNIVERSITY&nbsp; / &nbsp;ZHIXING</p>
              <h1 id="campus-login-title">
                在西电，
                <br />
                <em>知行合一。</em>
              </h1>
            </div>
            <p className="campus-login__intro-note">
              校园里的每一次相遇，
              <br />
              都让所学有了回响。
            </p>
          </div>

          <div className="campus-login__gallery-wrap" id="campus-gallery">
            <div className="campus-login__caption" aria-live="polite">
              <p>{activeImage.title}</p>
              <span>{activeImage.place}</span>
            </div>
            <div className="campus-login__gallery-controls" aria-label="校园照片切换">
              <button type="button" onClick={() => moveSlide(-1)} aria-label="上一张校园照片">
                ←
              </button>
              <div aria-live="polite">
                <strong>{String(activeIndex + 1).padStart(2, '0')}</strong>
                <span>/ 04</span>
              </div>
              <button type="button" onClick={() => moveSlide(1)} aria-label="下一张校园照片">
                →
              </button>
            </div>
          </div>

          <footer className="campus-login__story-footer">
            <p>
              “厚德、求真、励学、笃行”
              <br />
              每一次登录，都是新的出发。
            </p>
            <span>34.126° N&nbsp; / &nbsp;108.834° E</span>
          </footer>
        </section>

        <section className="campus-login__auth" id="campus-auth" aria-labelledby="campus-auth-title">
          <div className="campus-login__auth-inner">
            <p className="campus-login__auth-label">学校统一身份认证</p>
            <h2 id="campus-auth-title">
              欢迎回到
              <br />
              <span>知行。</span>
            </h2>

            <button type="button" className="campus-login__submit" onClick={login} disabled={loading}>
              <span>{loading ? '正在登录…' : '一站式登录'}</span>
              <span aria-hidden="true">↗</span>
            </button>
            {authError ? (
              <p className="campus-login__error" role="alert">
                {authError}
              </p>
            ) : null}

            <div className="campus-login__auth-foot">
              <span>学校账号由学校认证服务校验</span>
              <span className="campus-login__legal-links">
                <a href="/terms">使用条款</a>
                <a href="/privacy-policy">隐私说明</a>
              </span>
            </div>
          </div>
          <a className="campus-login__mobile-cue" href="#campus-auth">
            向下登录 <span aria-hidden="true">↓</span>
          </a>
        </section>
      </div>
    </main>
  );
}
