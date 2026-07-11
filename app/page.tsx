import Hero from '@/components/homepage/Hero';
import Explorer from '@/components/homepage/Explorer';
import Newsletter from '@/components/homepage/Newsletter';
import { HomepageInlineAd, FooterLeaderboardAd } from '@/components/ads/HomepageAds';

export default function HomePage() {
  return (
    <>
      <Hero />
      <Explorer />
      <HomepageInlineAd />
      <Newsletter />
      <FooterLeaderboardAd />
    </>
  );
}
