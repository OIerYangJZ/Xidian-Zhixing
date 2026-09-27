import SvgArrowReply from '@/svg_components/ArrowReply';
import SvgAtSign from '@/svg_components/AtSign';
import SvgComment from '@/svg_components/Comment';
import SvgHeart from '@/svg_components/Heart';
import SvgProfile from '@/svg_components/Profile';
import type { ActivityType } from '@/types/definitions';
import { RepostIcon } from './icons/RepostIcon';

function CreateFollowNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-primary p-1 ring-2 ring-background">
      <SvgProfile width={18} height={18} stroke="white" />
    </div>
  );
}
function LikeNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-rose-500 p-1 ring-2 ring-background">
      <SvgHeart width={18} height={18} stroke="white" />
    </div>
  );
}
function MentionNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-primary p-1 ring-2 ring-background">
      <SvgAtSign width={18} height={18} stroke="white" />
    </div>
  );
}
function RepostNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-emerald-500 p-1 text-white ring-2 ring-background">
      <RepostIcon width={16} height={16} />
    </div>
  );
}
function CreateCommentNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-sky-500 p-1 ring-2 ring-background">
      <SvgComment width={18} height={18} stroke="white" />
    </div>
  );
}
function CreateReplyNotificationIcon() {
  return (
    <div className="absolute -bottom-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-sky-500 p-1 ring-2 ring-background">
      <SvgArrowReply width={18} height={18} stroke="white" />
    </div>
  );
}

const ActivityIcons: Record<ActivityType, () => JSX.Element> = {
  CREATE_FOLLOW: () => <CreateFollowNotificationIcon />,

  POST_LIKE: () => <LikeNotificationIcon />,
  POST_MENTION: () => <MentionNotificationIcon />,

  CREATE_COMMENT: () => <CreateCommentNotificationIcon />,
  COMMENT_LIKE: () => <LikeNotificationIcon />,
  COMMENT_MENTION: () => <MentionNotificationIcon />,

  CREATE_REPLY: () => <CreateReplyNotificationIcon />,
  REPLY_LIKE: () => <LikeNotificationIcon />,
  REPLY_MENTION: () => <MentionNotificationIcon />,

  POST_FAVORITE: () => <LikeNotificationIcon />,
  POST_REPOST: () => <RepostNotificationIcon />,
  REPORT_RESULT: () => <MentionNotificationIcon />,
  SYSTEM: () => <MentionNotificationIcon />,
};

export function ActivityIcon({ type }: { type: ActivityType }) {
  return <>{ActivityIcons[type]()}</>;
}
