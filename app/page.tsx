import Hero from '@/components/homepage/Hero';
import StatsBar from '@/components/homepage/StatsBar';
import Explorer from '@/components/homepage/Explorer';
import FeatureStrip from '@/components/homepage/FeatureStrip';
import Newsletter from '@/components/homepage/Newsletter';

export default function HomePage() {
  return (
    <>
      <Hero />
      <StatsBar />
      <Explorer />
      <FeatureStrip />
      <Newsletter />
    </>
  );
}
