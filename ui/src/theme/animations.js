export const animations = {
  fadeSlideIn: `
    @keyframes fadeSlideIn {
      0% {
        opacity: 0;
        transform: translateY(40px) scale(0.92);
        filter: blur(4px);
      }
      60% {
        opacity: 1;
        transform: translateY(0) scale(1);
        filter: blur(0px);
      }
      100% {
        opacity: 1;
      }
    }
  `,

  runeFadeIn: `
    @keyframes runeFadeIn {
      0% {
        opacity: 0;
        transform: translateY(20px);
      }
      100% {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `,

  globalEase: `
    * {
      transition: all 0.25s ease-out;
    }
  `,

  hoverShimmer: `
    .rune-hover:hover {
      filter: drop-shadow(0 0 6px var(--glow));
      transform: translateY(-2px);
    }
  `,
};
