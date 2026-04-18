import ChatRoom from "@/components/ChatRoom";

export default async function ChatPage({
  params,
}: {
  params: Promise<{ roomId: string }>;
}) {
  const { roomId } = await params;
  return <ChatRoom roomId={roomId} />;
}
