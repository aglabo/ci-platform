import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageSidebar() {
  return (
    <aside className={styles.sidebar}>
      <nav>
        <div className={styles.sidebarCategory}>ガイド</div>
        <ul className={styles.sidebarItems}>
          <li className={styles.sidebarItem}>
            <Link className={styles.sidebarLink} to="/user-guide">
              User Guide
            </Link>
          </li>
          <li className={styles.sidebarItem}>
            <Link className={styles.sidebarLink} to="/developer-guide">
              Developer Guide
            </Link>
          </li>
        </ul>
      </nav>
    </aside>
  );
}

function HomepageContent() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <div className={styles.content}>
      <header className={clsx('hero hero--primary', styles.heroBanner)}>
        <div className="container">
          <Heading as="h1" className="hero__title">
            {siteConfig.title}
          </Heading>
          <p className="hero__subtitle">{siteConfig.tagline}</p>
          <div className={styles.buttons}>
            <Link
              className="button button--secondary button--lg"
              to="/user-guide">
              User Guide
            </Link>
            <Link
              className="button button--secondary button--lg"
              to="/developer-guide">
              Developer Guide
            </Link>
          </div>
        </div>
      </header>
      <main>
        <HomepageFeatures />
      </main>
    </div>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`Hello from ${siteConfig.title}`}
      description="Description will go into a meta tag in <head />">
      <div className={styles.pageLayout}>
        <HomepageSidebar />
        <HomepageContent />
      </div>
    </Layout>
  );
}
