export default function RuneSection({ title, children }) {
  return (
    <section className="rune-section">
      <h2 className="rune-section__title">{title}</h2>
      <div className="rune-section__rule" />
      {children}
    </section>
  );
}
