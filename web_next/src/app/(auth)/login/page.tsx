import { CampusLoginExperience } from './CampusLoginExperience';
import './login.css';

export const metadata = {
  title: '西电知行 · 登录',
  description: '使用学校统一身份认证进入西电知行。',
};

export default function Page() {
  return <CampusLoginExperience />;
}
