'use client';

import { signIn } from 'next-auth/react';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { useLanguage } from '@/hooks/useLanguage';

const campusImages: Array<{ src: string; alt: [string, string]; title: [string, string]; place: [string, string] }> = [
  {
    src: '/campus-login/campus-courtyard.png',
    alt: ['长安校区中心广场与教学楼', 'Central plaza and teaching buildings at Chang’an Campus'],
    title: ['把目光放远', 'Look further'],
    place: ['长安校区 · 中心广场', 'Chang’an Campus · Central Plaza'],
  },
  {
    src: '/campus-login/campus-stone.png',
    alt: ['西电校名石与校园松林', 'Xidian name stone and campus pines'],
    title: ['从这里出发', 'Start from here'],
    place: ['西电校名石', 'Xidian name stone'],
  },
  {
    src: '/campus-login/campus-clock.png',
    alt: ['校园主楼与远山', 'The main campus building and distant hills'],
    title: ['让时间留下回响', 'Let time leave an echo'],
    place: ['校园主楼 · 晨光', 'Main Building · Morning light'],
  },
  {
    src: '/campus-login/campus-library.png',
    alt: ['图书馆与校园秋色', 'The library in autumn'],
    title: ['在书页之间相遇', 'Meet between the pages'],
    place: ['图书馆 · 秋日', 'Library · Autumn'],
  },
];
const campusImageStyles = campusImages.map((image) => ({ backgroundImage: `url("${image.src}")` }));

export function CampusLoginExperience() {
  const { t } = useLanguage();
  const [activeIndex, setActiveIndex] = useState(2);
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
      if (errorCode)
        setAuthError(t('学校统一认证未完成，请重新登录。', 'Xidian sign-in was not completed. Please try again.'));
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
            setAuthError(t('登录状态已失效，请重新登录。', 'Your sign-in session has expired. Please try again.'));
            setLoading(false);
          }
          return;
        }
        if (status === 'pending') {
          timer = window.setTimeout(poll, 1000);
          return;
        }
        setAuthError(t('学校统一认证已失效，请重新登录。', 'Xidian sign-in has expired. Please try again.'));
        setLoading(false);
      } catch {
        if (!active) return;
        setAuthError(t('暂时无法确认登录状态，请重新登录。', 'We could not confirm your sign-in. Please try again.'));
        setLoading(false);
      }
    };
    poll();
    return () => {
      active = false;
      if (timer) window.clearTimeout(timer);
    };
  }, [t]);

  useEffect(() => {
    if (reducedMotion || paused) return undefined;
    const timer = window.setInterval(() => setActiveIndex((index) => (index + 1) % campusImages.length), 5200);
    return () => window.clearInterval(timer);
  }, [activeIndex, paused, reducedMotion]);

  const moveSlide = useCallback((amount: number) => {
    setActiveIndex((index) => (index + amount + campusImages.length) % campusImages.length);
  }, []);

  const login = useCallback(async () => {
    setLoading(true);
    setAuthError('');
    const requestedPath = new URLSearchParams(window.location.search).get('from') || '/feed';
    const callbackPath = requestedPath.startsWith('/') && !requestedPath.startsWith('//') ? requestedPath : '/feed';
    const useLocalAccount = process.env.NODE_ENV !== 'production' && process.env.NEXT_PUBLIC_LOCAL_TEST_AUTH === 'true';
    if (useLocalAccount) {
      try {
        const callbackUrl = new URL(callbackPath, window.location.origin).toString();
        const result = await signIn('local-test', { callbackUrl, redirect: false });
        if (!result?.ok || !result.url) throw new Error('local_login_failed');
        window.location.assign(result.url);
      } catch {
        setAuthError(
          t(
            '本地登录暂不可用，请检查开发数据库是否已启动。',
            'Local sign-in is unavailable. Check that the development database is running.',
          ),
        );
        setLoading(false);
      }
      return;
    }
    try {
      const response = await fetch('/api/auth/xidian/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ callbackUrl: callbackPath }),
      });
      const result = await response.json();
      if (!response.ok || !result?.data?.authorizeUrl) throw new Error('auth_setup_failed');
      window.location.assign(result.data.authorizeUrl);
    } catch {
      setAuthError(
        t('学校统一认证暂时不可用，请稍后重试。', 'Xidian sign-in is temporarily unavailable. Please try again later.'),
      );
      setLoading(false);
    }
  }, [t]);

  return (
    <main className="campus-login">
      <header className="campus-login__topbar">
        <Link className="campus-login__brand" href="/" aria-label={t('西电知行首页', 'Xidian Zhixing home')}>
          <img className="campus-login__brand-logo" src="/campus-login/zhixing-logo.jpg" alt="" />
          <span>{t('西电知行', 'Xidian Zhixing')}</span>
        </Link>
        <nav className="campus-login__top-links" aria-label={t('登录页导航', 'Sign-in navigation')}>
          <a href="#campus-gallery">{t('认识校园', 'Explore campus')}</a>
          <a href="#campus-auth">{t('统一认证', 'Sign in')}</a>
        </nav>
      </header>

      <div className="campus-login__layout">
        <section
          className="campus-login__story"
          aria-labelledby="campus-login-title"
          aria-label={t(activeImage.alt[0], activeImage.alt[1])}
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => setPaused(false)}>
          {campusImages.map((image, index) => (
            <div
              key={image.src}
              className={`campus-login__photo-layer${activeIndex === index ? 'is-active' : ''}`}
              style={campusImageStyles[index]}
              aria-hidden="true"
            />
          ))}
          <div className="campus-login__story-grid" aria-hidden="true" />
          <div className="campus-login__intro">
            <div className="campus-login__intro-title">
              <p className="campus-login__eyebrow">XIDIAN UNIVERSITY&nbsp; / &nbsp;ZHIXING</p>
              <h1 id="campus-login-title">
                {t('在西电，', 'At Xidian,')}
                <br />
                <em>{t('知行合一。', 'learn and act as one.')}</em>
              </h1>
            </div>
            <p className="campus-login__intro-note">
              {t('校园里的每一次相遇，', 'Every encounter on campus')}
              <br />
              {t('都让所学有了回响。', 'gives what we learn a place to resonate.')}
            </p>
          </div>

          <div className="campus-login__gallery-wrap" id="campus-gallery">
            <div className="campus-login__caption" aria-live="polite">
              <p>{t(activeImage.title[0], activeImage.title[1])}</p>
              <span>{t(activeImage.place[0], activeImage.place[1])}</span>
            </div>
            <div className="campus-login__gallery-controls" aria-label={t('校园照片切换', 'Campus photo controls')}>
              <button
                type="button"
                onClick={() => moveSlide(-1)}
                aria-label={t('上一张校园照片', 'Previous campus photo')}>
                ←
              </button>
              <div aria-live="polite">
                <strong>{String(activeIndex + 1).padStart(2, '0')}</strong>
                <span>/ 04</span>
              </div>
              <button type="button" onClick={() => moveSlide(1)} aria-label={t('下一张校园照片', 'Next campus photo')}>
                →
              </button>
            </div>
          </div>

          <footer className="campus-login__story-footer">
            <p>
              {t('“厚德、求真、励学、笃行”', '“Integrity, truth, diligence, and action”')}
              <br />
              {t('每一次登录，都是新的出发。', 'Every sign-in is a new beginning.')}
            </p>
            <span>34.126° N&nbsp; / &nbsp;108.834° E</span>
          </footer>
        </section>

        <section className="campus-login__auth" id="campus-auth" aria-labelledby="campus-auth-title">
          <div className="campus-login__auth-inner">
            <p className="campus-login__auth-label">{t('学校统一身份认证', 'Xidian single sign-on')}</p>
            <h2 id="campus-auth-title">
              {t('欢迎回到', 'Welcome back to')}
              <br />
              <span>{t('知行。', 'Zhixing.')}</span>
            </h2>
            <p className="campus-login__auth-description">
              {t(
                '用校园身份开启今天。登录后，课程、校园服务与同学社区都在这里。',
                'Sign in with your campus account to access courses, campus services, and the student community.',
              )}
            </p>

            <button type="button" className="campus-login__submit" onClick={login} disabled={loading}>
              <span>{loading ? t('正在登录…', 'Signing in…') : t('一站式登录', 'Sign in with Xidian')}</span>
              <span aria-hidden="true">↗</span>
            </button>
            {authError ? (
              <p className="campus-login__error" role="alert">
                {authError}
              </p>
            ) : null}

            <div className="campus-login__auth-foot">
              <span>{t('学校账号由学校认证服务校验', 'Your university account is verified by Xidian.')}</span>
              <span className="campus-login__legal-links">
                <a href="/terms">{t('使用条款', 'Terms')}</a>
                <a href="/privacy-policy">{t('隐私说明', 'Privacy')}</a>
              </span>
            </div>
          </div>
          <a className="campus-login__mobile-cue" href="#campus-auth">
            {t('向下登录', 'Scroll to sign in')} <span aria-hidden="true">↓</span>
          </a>
        </section>
      </div>
    </main>
  );
}
