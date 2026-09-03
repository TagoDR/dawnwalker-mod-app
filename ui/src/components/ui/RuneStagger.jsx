export default function RuneStagger({ index, children }) {
  const delay = `${index * 120}ms`; // 120ms stagger per rune

  return (
    <div
      style={{
        opacity: 0,
        animation: `runeFadeIn 0.6s ease-out ${delay} forwards`,
      }}
    >
      {children}
    </div>
  );
}
