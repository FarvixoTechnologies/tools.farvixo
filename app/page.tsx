import Hero from '@/components/homepage/Hero';
import Explorer from '@/components/homepage/Explorer';
import FeatureStrip from '@/components/homepage/FeatureStrip';
import Newsletter from '@/components/homepage/Newsletter';
import { HomepageInlineAd, FooterLeaderboardAd } from '@/components/ads/HomepageAds';

export default function HomePage() {
  return (
    <>
      <Hero />
      <Explorer />
      <HomepageInlineAd />
      <FeatureStrip />
      <Newsletter />
      <FooterLeaderboardAd />
    </>
  );
}
